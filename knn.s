	.data
	.align 2
parse_buf:		.space	4096	# char[4096]
train_values:		.word	0	# float *
train_labels:		.word	0	# float *
test_values:		.word	0	# float *
distance_vec:		.word	0	# float *
nrow_train:		.word	0	# int
nrow_test:		.word	0	# int
dimension:		.word	0	# int
k:			.word	0	# int
float_zero:		.float	0
float_ten:		.float	10
float_dot_one:		.float	0.1
filename_train_values:	.asciiz	"train_values.txt"
filename_train_labels:	.asciiz	"train_labels.txt"
filename_test_values:	.asciiz	"test_values.txt"
filename_output:	.asciiz	"output.txt"
str_newline:		.asciiz	"\n"
str_float_zero:		.asciiz "0.0"
str_float_one:		.asciiz "1.0"
str_err_diff_nrow:	.asciiz	"error: train_values.txt and train_labels.txt have different number of lines\n"
str_err_diff_dim:	.asciiz	"error: train_values.txt and test_values.txt have different number of columns\n"
str_err_diff_dim_in:	.asciiz	": error: different number of columns in line "
str_err_open_failed:	.asciiz	": error: could not open file\n"
str_err_k_lt_one:	.asciiz	"error: value of k must be greater than 0\n"
	.text

.globl	main
main:
	jal	egg

	# Get value of k and save to `k`
	li	$v0, 5
	syscall
	blez	$v0, err_k_lt_one	# k <= 0 ?
	sw	$v0, k

	# Parse train_values.txt and save `nrow` to $s0 and `dim` to $s2
	la	$a0, filename_train_values
	la	$a1, train_values
	jal	parse
	move	$s0, $v0
	move	$s2, $v1
	# Also save to static variables
	sw	$s0, nrow_train
	sw	$s2, dimension

	# Parse train_labels.txt
	la	$a0, filename_train_labels
	la	$a1, train_labels
	jal	parse
	bne	$v0, $s0, err_diff_nrow	# nrow != nrow_train ?

	# Parse test_values.txt and save `nrow_test` to $s1
	la	$a0, filename_test_values
	la	$a1, test_values
	jal	parse
	bne	$v1, $s2, err_diff_dim	# ncol != dimension ?
	move	$s1, $v0

	mul	$a0, $s0, 4 # $a0 = nrow_train*4
	# Allocate `train_labels_surrogate` and save to $s3
	li	$v0, 9
	syscall
	move	$s3, $v0
	# Allocate `distance_vec` and save allocated address
	li	$v0, 9
	syscall
	sw	$v0, distance_vec

	li	$s4, 0		# $s4 = i = 0
	mul	$s5, $s2, 4	# $s5 = dim*4
	lw	$s6, train_labels	# $s6 = train_labels
main_loop:
	mul	$t8, $s1, $s5
	bge	$s4, $t8, main_loop_end	# i >= nrow_test*dim*4 ?

	# Copy `train_labels` to `train_labels_surrogate`
	move	$t0, $s6	# $t0 = train_labels
	move	$t1, $s3	# $t1 = train_labels_surrogate
	mul	$t2, $s0, $s5
	add	$t2, $t2, $t0	# $t2 = train_labels_surrogate + nrow_train*dim*4
memcpy_loop:
	bge	$t0, $t2, memcpy_loop_end
	lw	$t8, ($t0)
	sw	$t8, ($t1)
	addi	$t0, $t0, 4
	addi	$t1, $t1, 4
	j	memcpy_loop
memcpy_loop_end:

	# knn(train_values, train_labels, test_values)
	lw	$a0, train_values
	move	$a1, $s3
	lw	$a2, test_values
	add	$a2, $a2, $s4
	jal	knn	# $v0 = n

	# Print `n`
	beqz	$v0, main_write_zero	# n == 0 ?
	la	$a0, str_float_one	# print 1.0
	j	main_write_syscall
main_write_zero:
	la	$a0, str_float_zero	# print 0.0
main_write_syscall:
	li	$v0, 4
	syscall

	add	$s4, $s4, $s5	# i += dim*4

	# Print newline if we're not in the last line
	mul	$t8, $s1, $s5
	beq	$s4, $t8, main_loop_end	# i >= nrow_test*dim*4 ?
	#       $v0 is already 4
	la	$a0, str_newline
	syscall

	j	main_loop
main_loop_end:
	j	exit

# $a0:	float *train_values
# $a1:	float *train_labels
# $a2:	float *test_values
.globl	knn
knn:
	subi	$sp, $sp, 8
	sw	$ra, 0($sp)
	sw	$a1, 4($sp)

	# Calculate distance between the first vector in the address pointed by
	# `test_values` and all vectors in `train_values`
	lw	$t0, dimension
	mul	$t0, $t0, 4		# $t0 = dim*4
	lw	$t1, distance_vec	# $t1 = distance_vec
	lw	$t2, nrow_train
	mul	$t2, $t2, $t0
	add	$t2, $t2, $a0		# $t2 = train_values + xtrain_nrow*dim*4
knn_distance_loop:
	bge	$a0, $t2, knn_distance_loop_end	# train_values >= train_values + xtrain_nrow*dim*4 ?
	lwc1	$f0, float_zero	# $f0 = sum = 0
	move	$t3, $a2	# $t3 = test_values
	add	$t4, $t3, $t0	# $t4 = test_values + dim*4
knn_distance_single_loop:
	bge	$t3, $t4, knn_distance_single_loop_end	# test_values >= test_values + dim*4 ?
	lwc1	$f1, ($t3)	# $f1 = *test_values
	lwc1	$f2, ($a0)	# $f2 = *train_values
	sub.s	$f1, $f1, $f2	# $f1 = tmp = *test_values - *train_values
	mul.s	$f1, $f1, $f1	# tmp *= tmp
	add.s	$f0, $f0, $f1	# sum += tmp
	addi	$t3, $t3, 4	# ++test_values
	addi	$a0, $a0, 4	# ++train_values
	j	knn_distance_single_loop
knn_distance_single_loop_end:
	sqrt.s	$f0, $f0	# sum = sqrt(sum)
	swc1	$f0, ($t1)	# *distance_vec = result
	addi	$t1, $t1, 4	# ++distance_vec
	j	knn_distance_loop
knn_distance_loop_end:

	# quicksort_reflected(distance_vec, train_labels, 0, nrow_train);
	lw	$a0, distance_vec
	li	$a2, 0
	lw	$a3, nrow_train
	jal	quicksort_reflected

	# Prepare for `knn_get_n_loop`
	li	$v0, 0		# $v0 = n = 0
	lw	$t0, 4($sp)	# $t0 = train_labels
	lw	$t8, k		# $t8 = k
	mul	$t1, $t8, 4
	add	$t1, $t1, $t0	# $t1 = train_labels + k*4
	lw	$t2, nrow_train
	mul	$t2, $t2, 4
	add	$t2, $t2, $t0	# $t2 = train_labels + nrow_train*4
	li	$t3, -1		# $t3 = -1
	lwc1	$f0, float_zero	# $f0 = 0.0

	# If `k` is even, consider only the `k-1` closest vectors
	rem	$t8, $t8, 2
	bnez	$t8, knn_get_n_loop	# k % 2 != 0 ?
	subi	$t1, $t1, 4	# $t1 -= 4

knn_get_n_loop:
	bge	$t0, $t1, knn_get_n_loop_end	# train_labels >= train_labels + k*4 ?
	bge	$t0, $t2, knn_get_n_loop_end	# train_labels >= nrow_train*4 ?
	lwc1	$f30, ($t0)	# $f30 = *train_labels
	c.eq.s	$f0, $f30
	li	$t8, 1		# $t8 = 1
	movt	$t8, $t3	# if *train_labels == 0 then $t8 = -1
	add	$v0, $v0, $t8	# n += $t8
	addi	$t0, $t0, 4	# ++train_labels
	j	knn_get_n_loop
knn_get_n_loop_end:
	sgt	$v0, $v0, 0	# n = n > 0

	lw	$ra, 0($sp)
	addi	$sp, $sp, 8
	jr	$ra

	# Macros used in `count_row_col` and `parse`
.macro	bspc %byte, %label
	# Branch if SPaCe: branch to %label if %byte is whitespace character
	beq	%byte, ' ', %label
	subi	$t9, %byte, '\t'
	blt	$t9, 5, %label
.end_macro
.macro	skpspc %base, %index
	# SKiP SPaCe: skip spaces in %base, starting from %index
skpspc:
	addi	%index, %index, 1
	add	$t8, %index, %base
	lbu	$t8, ($t8)
	bspc	$t8, skpspc
.end_macro

# $a0:	filename
# ret:	$v0 (nrow) e $v1 (ncol)
.globl	count_row_col
count_row_col:
.macro	count_row_col_read_fd
	li	$v0, 14
	syscall
	blez	$v0, count_row_col_end	# nread <= 0 ?
	bge	$v0, 4096, _continue	# nread >= 4096 ?
	add	$t8, $a1, $v0
	lbu	$t8, -1($t8)		# $t8 = parse_buf[nread - 1]
	bspc	$t8, _continue
	addi	$t0, $t0, 1		# ++nrow
_continue:
.end_macro

	# Open fd of `filename` and save to $a0
	li	$v0, 13
	li	$a1, 0
	li	$a2, 0
	syscall
	bltz	$v0, err_open_failed	# fd < 0 ?
	move	$v1, $a0		# save `filename` to $v1 before overwriting $a0
	move	$a0, $v0

	la	$a1, parse_buf
	li	$a2, 4096
	li	$t0, 0	# $t0 = nrow = 0
	li	$t1, 0	# $t1 = ncol = 0
	li	$t2, 0	# $t2 = cur_ncol = 0

count_row_col_read1:
	count_row_col_read_fd
	li	$t3, 0	# $t3 = i = 0

count_row_col_loop1:
	bge	$t3, $v0, count_row_col_read1	# i >= nread ?

	add	$t8, $t3, $a1
	lbu	$t8, ($t8)
	beq	$t8, ',', count_row_col_loop1_comma
	bspc	$t8, count_row_col_loop1_space

	j	count_row_col_loop1_continue

count_row_col_loop1_comma:
	addi	$t2, $t2, 1	# ++cur_ncol
	j	count_row_col_loop1_continue

count_row_col_loop1_space:
	addi	$t1, $t2, 1	# ncol = cur_ncol + 1
	li	$t2, 0		# cur_ncol = 0
	addi	$t0, $t0, 1	# ++nrow
	skpspc	$a1, $t3
	j	count_row_col_loop2

count_row_col_loop1_continue:
	addi	$t3, $t3, 1	# ++i
	j	count_row_col_loop1

count_row_col_read2:
	count_row_col_read_fd
	li	$t3, 0	# $t3 = i = 0

count_row_col_loop2:
	bge	$t3, $v0, count_row_col_read2	# i >= nread ?

	add	$t8, $t3, $a1
	lbu	$t8, ($t8)
	beq	$t8, ',', count_row_col_loop2_comma
	bspc	$t8, count_row_col_loop2_space

	j	count_row_col_loop2_continue

count_row_col_loop2_comma:
	addi	$t2, $t2, 1	# ++cur_ncol
	j	count_row_col_loop2_continue

count_row_col_loop2_space:
	addi	$t2, $t2, 1
	bne	$t2, $t1, count_row_col_diff_dim	# cur_ncol != ncol ?
	li	$t2, 0		# cur_ncol = 0
	addi	$t0, $t0, 1	# ++nrow
	skpspc	$a1, $t3
	j	count_row_col_loop2

count_row_col_loop2_continue:
	addi	$t3, $t3, 1	# ++i
	j	count_row_col_loop2

count_row_col_diff_dim:
	# Print "error: different number of columns..."
	li	$v0, 4
	move	$a0, $v1
	syscall
	li	$v0, 4
	la	$a0, str_err_diff_dim_in
	syscall
	li	$v0, 1
	move	$a0, $t0
	addi	$a0, $a0, 1
	syscall
	j	exit_err

count_row_col_end:
	# Close fd
	li	$v0, 16
	# $a0 already contains the fd number
	syscall
	move	$v0, $t0
	move	$v1, $t1
	jr	$ra

# $a0:	filename
# $a1:	float *vec
# ret:	$v0 (nrow) e $v1 (ncol)
.globl	parse
parse:
.macro	movec.s %cur, %vec, %j
	# vec[j] = cur
	mul	$t8, %j, 4
	add	$t8, $t8, %vec
	swc1	%cur, ($t8)
.end_macro

.macro	ptrdfd
	# Parse Try ReaD FD
	li	$v0, 14
	syscall
	bgtz	$v0, _continue	# nread > 0 ?
	c.eq.s	$f0, $f8	# cur == 0.0 ?
	bc1t	parse_end
	movec.s	$f0, $t2, $t4
	j	parse_end
_continue:
.end_macro

	subi	$sp, $sp, 12
	sw	$ra, 0($sp)
	sw	$a0, 4($sp)
	sw	$a1, 8($sp)

	# Get `nrow` and `ncol`
	jal	count_row_col
	move	$t0, $v0	# $t0 = nrow
	move	$t1, $v1	# $t1 = ncol

	# Allocate vector with (nrow*ncol*4) bytes
	li	$v0, 9
	mul	$a0, $t0, $t1
	mul	$a0, $a0, 4
	syscall
	lw	$t2, 8($sp)
	sw	$v0, ($t2)	# Save allocated address to `vec`
	move	$t2, $v0	# ...and also to $t2

	# Open fd of `filename`
	li	$v0, 13
	lw	$a0, 4($sp)
	li	$a1, 0
	li	$a2, 0
	syscall
	bltz	$v0, err_open_failed	# fd < 0 ?

	move	$a0, $v0
	la	$a1, parse_buf
	li	$a2, 4096
	li	$t4, 0	# $t4 = j = 0
	lwc1	$f0, float_zero	# $f0 = cur = 0.0
	lwc1	$f1, float_zero	# $f1 = 0.0
	lwc1	$f2, float_ten	# $f2 = 10.0
parse_read:
	ptrdfd
	li	$t3, 0	# $t3 = i = 0
parse_loop:
	bge	$t3, $v0, parse_read	# i >= nread ?

	add	$t8, $t3, $a1
	lbu	$t8, ($t8)
	beq	$t8, '.', parse_dot
	beq	$t8, ',', parse_insert
	bspc	$t8, parse_insert

	# cur = cur*10 + (buf[i] - '0');
	subi	$t8, $t8, '0'
	mtc1	$t8, $f4	# move t8 to $f4
	cvt.s.w	$f4, $f4	# convert $f4 to float
	mul.s	$f0, $f0, $f2
	add.s	$f0, $f0, $f4

	addi	$t3, $t3, 1	# ++i
	j	parse_loop

parse_dot:
	lwc1	$f3, float_dot_one	# $f3 = mul = 0.1
	addi	$t3, $t3, 1		# ++i
parse_dot_loop:
	blt	$t3, $v0, parse_dot_continue	# i >= nread ?
	ptrdfd
	li	$t3, 0	# $t3 = i = 0
parse_dot_continue:
	add	$t8, $t3, $a1
	lbu	$t8, ($t8)
	beq	$t8, ',', parse_insert
	bspc	$t8, parse_insert

	# cur += mul*(buf[i] - '0');
	subi	$t8, $t8, '0'
	mtc1	$t8, $f4	# move $t8 to $f4
	cvt.s.w	$f4, $f4	# convert $f4 to float
	mul.s	$f4, $f4, $f3
	add.s	$f0, $f0, $f4

	div.s	$f3, $f3, $f2	# mul /= 10
	addi	$t3, $t3, 1	# ++i
	j	parse_dot_loop

parse_insert:
	movec.s	$f0, $t2, $t4
	lwc1	$f0, float_zero	# cur = 0.0
	addi	$t4, $t4, 1	# ++j
	skpspc	$a1, $t3
	j	parse_loop

parse_end:
	lw	$ra, 0($sp)
	addi	$sp, $sp, 12
	move	$v0, $t0
	move	$v1, $t1
	jr	$ra

# $a0:	float *a
# $a1:	float *b
# $a2:	int lo
# $a3:	int hi
# ret:	$v0
.globl	partition
partition:
.macro	swap %a, %b
	lw	$t6, (%a)
	lw	$t7, (%b)
	sw	$t6, (%b)
	sw	$t7, (%a)
.end_macro

	subi	$v0, $a2, 1
	mul	$v0, $v0, 4	# $v0 = (lo-1)*4 = p*4
	move	$t0, $a2
	mul	$t0, $t0, 4	# $t0 = i*4
	subi	$t1, $a3, 1
	mul	$t1, $t1, 4	# $t1 = (hi-1)*4
	add	$t8, $t1, $a0
	lwc1	$f0, ($t8)	# $f0 = pivot = a[hi - 1]
partition_loop:
	bge	$t0, $t1, partition_end	# i*4 >= (hi-1)*4 ?

	add	$t8, $t0, $a0	# $t8 = &a[i]
	lwc1	$f1, ($t8)	# $f1 = a[i]
	c.le.s	$f1, $f0	# a[i] <= pivot ?
	bc1f	partition_continue
	addi	$v0, $v0, 4	# p += 4

	add	$t9, $v0, $a0	# $t9 = &a[p]
	swap	$t8, $t9	# swap(&a[p], &a[i])
	add	$t8, $v0, $a1	# $t9 = &b[p]
	add	$t9, $t0, $a1	# $t8 = &b[i]
	swap	$t8, $t9	# swap(&b[p], &b[i])

partition_continue:
	addi	$t0, $t0, 4	# i += 4
	j	partition_loop

partition_end:
	addi	$v0, $v0, 4	# p += 4

	add	$t8, $t1, $a0	# $t9 = &a[hi - 1]
	add	$t9, $v0, $a0	# $t8 = &a[p]
	swap	$t8, $t9	# swap(&a[hi - 1], &a[p])
	add	$t8, $t1, $a1	# $t9 = &b[hi - 1]
	add	$t9, $v0, $a1	# $t8 = &b[p]
	swap	$t8, $t9	# swap(&b[hi - 1], &b[p])

	div	$v0, $v0, 4	# p /= 4
	jr	$ra

# $a0:	float *a
# $a1:	float *b
# $a2:	int lo
# $a3:	int hi
.globl	quicksort_reflected
quicksort_reflected:
	blt	$a3, 2, quicksort_reflected_end		# hi < 2 ?
	bge	$a2, $a3, quicksort_reflected_end	# lo <= hi ?

	# Save values to the stack
	subi	$sp, $sp, 20
	sw	$ra, 0($sp)
	sw	$a0, 4($sp)
	sw	$a1, 8($sp)
	sw	$a3, 12($sp)

	# partition(a, b, lo, hi)
	jal	partition
	sw	$v0, 16($sp)	# $v0 = p

	# quicksort_reflected(a, b, lo, p)
	move	$a3, $v0
	jal	quicksort_reflected

	# quicksort_reflected(a, b, p + 1, hi)
	lw	$a0, 4($sp)
	lw	$a1, 8($sp)
	lw	$a2, 16($sp)
	addi	$a2, $a2, 1
	lw	$a3, 12($sp)
	jal	quicksort_reflected

	lw	$ra, 0($sp)
	addi	$sp, $sp, 20
quicksort_reflected_end:
	jr	$ra

.include	"egg.s"

	# Error handling
err_diff_nrow:
	li	$v0, 4
	la	$a0, str_err_diff_nrow
	syscall
	j	exit_err
err_diff_dim:
	li	$v0, 4
	la	$a0, str_err_diff_dim
	syscall
	j	exit_err
err_k_lt_one:
	li	$v0, 4
	la	$a0, str_err_k_lt_one
	syscall
	j	exit_err
err_open_failed:
	li	$v0, 4
	syscall
	li	$v0, 4
	la	$a0, str_err_open_failed
	syscall
	j	exit_err

exit:
	# exit(0)
	li	$v0, 10
	syscall
exit_err:
	# exit(1)
	li	$v0, 17
	li	$a0, 1
	syscall
