ec_ocl
======

Elliptic Curve OpenCL implementation

* Status:

test program executes 8 workitems in 2 groups, read and store, exist mainly for execution debugging from the kernel itself<br />
host program compiles test.cl kernel, allocate and do memory transfers using _constant and _local address spaces.<br />
test.cl kernel execute mostly the needed functions, some are missing; writes on _local address space, read from _constant and then exports to _global<br />
<pre>
cl_1 # ./demo test.cl point_mul
Check OpenCL environtment
Connecting to OpenCL device:    X.Org AMD PALM
CL_DEVICE_MAX_COMPUTE_UNITS     2
CL_DEVICE_MAX_WORK_GROUP_SIZE   256
CL_DEVICE_LOCAL_MEM_SIZE        32768b
Building from OpenCL source:    test.cl
Compile/query OpenCL_program:   point_mul
CL_KERNEL_WORK_GROUP_SIZE       256
CL_KERNEL_LOCAL_MEM_SIZE        32b
global:8, local:4, (should be): 2 groups
structs size: 64b, 108b
sets:8, total of 2560b needed, allocated _local: 128b
Read back, Mapping buffer:      320b
kernel execution time:          1.00 ms
i,      gid     lid     lsz     gsz        Gsz Gid off	stride5
0       0       0       4       8       |  2,  0,  0,	 0
1       1       1       4       8       |  2,  0,  0,	 5
2       2       2       4       8       |  2,  0,  0,	10
3       3       3       4       8       |  2,  0,  0,	15
4       4       0       4       8       |  2,  1,  4,	20
5       5       1       4       8       |  2,  1,  4,	25
6       6       2       4       8       |  2,  1,  4,	30
7       7       3       4       8       |  2,  1,  4,	35
</pre>
