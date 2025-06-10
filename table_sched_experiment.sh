#!/bin/bash

# فعال کردن ماژول‌های لازم
modprobe sched_trace 2>/dev/null
sleep 1

# تنظیم پلاگین زمان‌بند به sched_static
echo "sched_static" > /proc/litmus/sched_plugin
sleep 1

# ایجاد جدول زمان‌بندی اولیه (۲ کار)
cat > /root/table_small.txt <<EOL
0 10000000 0
10000000 20000000 1
EOL

# بارگذاری جدول کوچک
echo "بارگذاری جدول کوچک (۲ ردیف):"
cat /root/table_small.txt > /proc/litmus/static
sleep 1

# اجرای کارهای بلادرنگ
echo "شروع کارها با جدول کوچک..."
rtspin -p 0 -I 0 10000 20000 100 &
PID1=$!
rtspin -p 0 -I 1 10000 20000 100 &
PID2=$!

# منتظر ماندن برای اتمام کارها
sleep 10
kill $PID1 $PID2 2>/dev/null
wait $PID1 $PID2 2>/dev/null
echo "کارها با جدول کوچک تکمیل شد."

# ایجاد جدول بزرگ‌تر (۴ کار)
cat > /root/table_large.txt <<EOL
0 5000000 0
5000000 10000000 1
10000000 15000000 0
15000000 20000000 1
EOL

# بارگذاری جدول بزرگ
echo "بارگذاری جدول بزرگ (۴ ردیف):"
cat /root/table_large.txt > /proc/litmus/static
sleep 1

# اجرای کارها با جدول بزرگ
echo "شروع کارها با جدول بزرگ..."
rtspin -p 0 -I 0 10000 20000 100 &
PID1=$!
rtspin -p 0 -I 1 10000 20000 100 &
PID2=$!

# منتظر ماندن برای اتمام کارها
sleep 10
kill $PID1 $PID2 2>/dev/null
wait $PID1 $PID2 2>/dev/null
echo "کارها با جدول بزرگ تکمیل شد."

# آزمایش اندازه جدول‌های بزرگ‌تر
echo "آزمایش بارگذاری جدول‌های بزرگ‌تر:"
for exponent in {1..8}; do
    rows=$((2**$exponent))
    echo "ایجاد جدول با $rows ردیف..."
    
    # تولید جدول به صورت پویا
    echo -n "" > /root/table_$rows.txt
    for ((i=0; i<$rows; i++)); do
        start=$((i * 10000000))
        end=$(( (i+1) * 10000000 ))
        task=$((i % 2))
        echo "$start $end $task" >> /root/table_$rows.txt
    done
    
    # اندازه‌گیری زمان بارگذاری
    echo "زمان بارگذاری جدول $rows ردیف:"
    time (cat /root/table_$rows.txt > /proc/litmus/static)
    sleep 1
done

echo "آزمایش‌ها تکمیل شد!"