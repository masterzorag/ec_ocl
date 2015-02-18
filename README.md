ec_ocl
======

Elliptic Curve OpenCL implementation

* Status:

cl_amd
-------
test program executes 8 workitems in 2 groups, read and store, exist mainly for execution debugging from the kernel itself<br />
host program compiles test.cl kernel, allocate and do memory transfers using _constant and _local address spaces.<br />
test.cl kernel execute mostly the needed functions, some are missing; writes on _local address space, read from _constant and then exports to _global<br />
<pre>
cl_amd # ./demo ec_p_mul.cl point_mul
cl_amd # ./demo ec_p_mul.cl point_mul
Check OpenCL environtment
Connecting to OpenCL device:    AuthenticAMD AMD E-350 Processor
CL_DEVICE_MAX_COMPUTE_UNITS     2
CL_DEVICE_MAX_WORK_GROUP_SIZE   1024
CL_DEVICE_LOCAL_MEM_SIZE        32768b
Building from OpenCL source:    ec_p_mul.cl
Compile/query OpenCL_program:   point_mul
CL_KERNEL_WORK_GROUP_SIZE       1024
CL_KERNEL_LOCAL_MEM_SIZE        0b
global:8, local:4, (should be): 2 groups
structs size: 176b, 144b, 128b
sets:8, total of 2560b needed, allocated _local: 832b
Read back, Mapping buffer:      1408b
kernel execution time:          880.00 ms
i,      gid     lid0    lsize0  gid0/lsz0,      gsz0,   n_gr0,  lid5,   offset
0       0       0       4       8       |  2,  0,  0, 0
00542d46e7b3daac8aeb81e533873aabd6d74bb710
01718f862ebe9423bd661a65355aa1c86ba330f8 557e8ed53ffbfe2c990a121967b340f62e0e4fe2
0 0 4 8 2 0 0 0
1       1       1       4       8       |  2,  0,  0, 5
00542d46e7b3daac8aeb81e533873aabd6d74bb710
01718f862ebe9423bd661a65355aa1c86ba330f8 557e8ed53ffbfe2c990a121967b340f62e0e4fe2
1 1 4 8 2 0 0 5
2       2       2       4       8       |  2,  0,  0, 10
00540946e7b3daac8aeb81e533873aabd6d74bb710
0c75ec3cf59594e764cfdfb6868a27907f9996b2 73b547848b501f492c57045283833ae542a2c07b
2 2 4 8 2 0 0 10
3       3       3       4       8       |  2,  0,  0, 15
00542d46e7b3daac8aeb81e533873aabd6d74bb710
01718f862ebe9423bd661a65355aa1c86ba330f8 557e8ed53ffbfe2c990a121967b340f62e0e4fe2
3 3 4 8 2 0 0 15
4       4       0       4       8       |  2,  1,  4, 20
00542d46e7b3daac8aeb81e533873aabd6d74bb710
01718f862ebe9423bd661a65355aa1c86ba330f8 557e8ed53ffbfe2c990a121967b340f62e0e4fe2
4 0 4 8 2 1 4 20
5       5       1       4       8       |  2,  1,  4, 25
00542d46e7b3daac8aeb81e533873aabd6d74bb710
01718f862ebe9423bd661a65355aa1c86ba330f8 557e8ed53ffbfe2c990a121967b340f62e0e4fe2
5 1 4 8 2 1 4 25
6       6       2       4       8       |  2,  1,  4, 30
00542d46e7b3daac8aeb81e533873aabd6d74bb710
01718f862ebe9423bd661a65355aa1c86ba330f8 557e8ed53ffbfe2c990a121967b340f62e0e4fe2
6 2 4 8 2 1 4 30
7       7       3       4       8       |  2,  1,  4, 35
00542d46e7b3daac8aeb81e533873aabd6d74bb710
01718f862ebe9423bd661a65355aa1c86ba330f8 557e8ed53ffbfe2c990a121967b340f62e0e4fe2
7 3 4 8 2 1 4 35
Done!
</pre>
