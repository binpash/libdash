echo A
echo B; echo C
for i in 1 2; do
  echo "loop $i"
done
echo D | \
  cat
echo E
