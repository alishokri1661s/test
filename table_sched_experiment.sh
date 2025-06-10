#!/bin/bash

# ======================================================================
# تنظیمات پایه
# ======================================================================
MAJOR_CYCLE=1000  # سیکل اصلی به میلی‌ثانیه
OUTPUT_DIR="experiment_results"
mkdir -p $OUTPUT_DIR

# ======================================================================
# کامپایل تسک آزمایشی
# ======================================================================
cat << 'EOF' > td_task.c
#include <litmus.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <sys/syscall.h>

#define ms2ns(ms) ((ms) * 1000000LL)

pid_t gettid() { return syscall(SYS_gettid); }

int main() {
    lt_t start, now, next_cycle;
    int job_count = 0;
    const int MAX_JOBS = 10; // 10 اجرا برای هر آزمایش
    const lt_t MAJOR = ms2ns(1000); // سیکل اصلی 1000ms
    const lt_t WORK_PER_CYCLE = ms2ns(50); // 50ms کار در هر سیکل

    // تنظیم پارامترهای تسک بلادرنگ
    if (set_rt_task_param(gettid(), 0, 0, 0) != 0) {
        perror("set_rt_task_param failed");
        return 1;
    }

    // همگام‌سازی با شروع سیکل
    start = litmus_clock();
    next_cycle = ((start / MAJOR) + 1) * MAJOR;
    lt_sleep_until(next_cycle);

    while (job_count < MAX_JOBS) {
        lt_t work_done = 0;
        lt_t job_start = litmus_clock();

        printf("Job %d started at %llu ns\n", job_count, job_start);
        fflush(stdout);

        // اجرای کار به صورت قطعات 1ms
        while (work_done < WORK_PER_CYCLE) {
            lt_t seg_start = litmus_clock();
            lt_t seg_duration = (WORK_PER_CYCLE - work_done) > ms2ns(1) ? 
                                ms2ns(1) : (WORK_PER_CYCLE - work_done);
            
            // چرخه کاری
            while (litmus_clock() - seg_start < seg_duration) {}

            work_done += seg_duration;
            printf("  Segment at %llu: %llu ns done\n", seg_start, work_done);
            fflush(stdout);
        }

        // خواب تا شروع سیکل بعدی
        next_cycle = job_start + MAJOR;
        lt_sleep_until(next_cycle);
        job_count++;
    }
    return 0;
}
EOF

gcc td_task.c -o td_task -llitmus

# ======================================================================
# آزمایش‌ها
# ======================================================================
run_experiment() {
    exp_name=$1
    slots=$2

    echo "Running experiment: $exp_name"
    setsched P-RES
    resctl -d all  # حذف رزرویشن‌های قبلی

    # ایجاد رزرویشن جدولی
    resctl -n 1 -c 0 -t table-driven -m $MAJOR_CYCLE $slots
    
    # اجرای تسک
    rt_launch -r 1 -c 0 ./td_task > $OUTPUT_DIR/${exp_name}_output.log 2>&1
    
    sleep 12 # زمان برای اجرای کامل تسک (10 سیکل)
    resctl -d all
    echo "Experiment $exp_name completed"
}

# آزمایش 1: یک اسلات
run_experiment "single_slot" "'[0,50)'"

# آزمایش 2: دو اسلات
run_experiment "two_slots" "'[0,25)' '[500,525)'"

# آزمایش 3: چهار اسلات
run_experiment "four_slots" "'[0,12.5)' '[250,262.5)' '[500,512.5)' '[750,762.5)'"

# ======================================================================
# گزارش نتایج
# ======================================================================
echo -e "\n\n===== Experiment Results Summary ====="
for exp in single_slot two_slots four_slots; do
    echo -e "\nExperiment $exp:"
    grep "Job started" $OUTPUT_DIR/${exp}_output.log | tail -n 2
    grep "Segment at" $OUTPUT_DIR/${exp}_output.log | tail -n 5
done

echo "Results saved to: $OUTPUT_DIR/"
