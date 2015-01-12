/* 
	2014, masterzorag@gmail.com
	
	# clang -S -emit-llvm -o test.ll -x cl test.cl
	# gcc -o demo main.c -Wall -std=gnu99 -lOpenCL

gcc -o demo main.c -Wall -std=gnu99 \
	-I/opt/AMDAPPSDK-2.9-1/lib  \
	-L/opt/AMDAPPSDK-2.9-1/lib/x86/libOpenCL.so -lrt -Wl,-rpath,/opt/AMDAPPSDK-2.9-1/lib/x86 -lOpenCL
	
	# ./demo test.cl point_mul
	Check OpenCL environtment
	Connecting to OpenCL device:    X.Org AMD PALM
	CL_DEVICE_MAX_COMPUTE_UNITS     2
	CL_DEVICE_MAX_WORK_GROUP_SIZE   256
	CL_DEVICE_LOCAL_MEM_SIZE        32768b
	Building from OpenCL source:    test.cl
	Compile/query OpenCL_program:   point_mul
	CL_KERNEL_WORK_GROUP_SIZE       256
	CL_KERNEL_LOCAL_MEM_SIZE        149672255b
	global:8, local:4, (should be): 2 groups
	structs size: 48b, 108b
	sets:8, total of 2560b needed, allocated _local: 128b
	Read back, Mapping buffer:      384b
	kernel execution time:          1.00 ms
	
	i,      gid     lid0    lsize0  gid0/lsz0,      gsz0,   n_gr0,  lid5,   offset
	0       0       0       4       8       |  2,  0,  0, 0
	0 0
	010aff82b3ac72569ae645af3b527be133442131 46b8ec1e6d71e5ecb549614887d57a287df573cc
	1       1       1       4       8       |  2,  0,  0, 5
	0 0
	010aff82b3ac72569ae645af3b527be133442131 46b8ec1e6d71e5ecb549614887d57a287df573cc
	2       2       2       4       8       |  2,  0,  0, 10
	0 0
	010aff82b3ac72569ae645af3b527be133442131 46b8ec1e6d71e5ecb549614887d57a287df573cc
	3       3       3       4       8       |  2,  0,  0, 15
	0 0
	010aff82b3ac72569ae645af3b527be133442131 46b8ec1e6d71e5ecb549614887d57a287df573cc
	4       4       0       4       8       |  2,  1,  4, 20
	0 0
	010aff82b3ac72569ae645af3b527be133442131 46b8ec1e6d71e5ecb549614887d57a287df573cc
	5       5       1       4       8       |  2,  1,  4, 25
	0 0
	010aff82b3ac72569ae645af3b527be133442131 46b8ec1e6d71e5ecb549614887d57a287df573cc
	6       6       2       4       8       |  2,  1,  4, 30
	0 0
	010aff82b3ac72569ae645af3b527be133442131 46b8ec1e6d71e5ecb549614887d57a287df573cc
	7       7       3       4       8       |  2,  1,  4, 35
	0 0
	010aff82b3ac72569ae645af3b527be133442131 46b8ec1e6d71e5ecb549614887d57a287df573cc
	Done!
*/

#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <CL/cl.h>
typedef cl_uchar u8;
typedef cl_uint u32;

#include "cl_util.h"

typedef struct{
	u8 x[20];
	u8 y[20];
} point;

typedef struct{
	point P;
	u8 c;
	u8 dig;
	u8 unused;		//makes 64b %16 == 0
	u8 k[21];
} data;

typedef struct{
	u8 p[20];
	u8 a[20];
	u8 b[20];
	point G;
	u8 unused[12];		//makes 112b %16 == 0
} Elliptic_Curve;

typedef struct{
	u32 data[8];
} debug;

typedef char s8;
typedef unsigned long long int u64;

u64 _x_to_u64(const s8 *hex){
	u64 t = 0, res = 0;
	u32 len = strlen(hex);
	char c;
	while(len--){
		c = *hex++;
		if(c >= '0' && c <= '9')	t = c - '0';
		else if(c >= 'a' && c <= 'f')	t = c - 'a' + 10;
		else if(c >= 'A' && c <= 'F')	t = c - 'A' + 10;
		else				t = 0;
		res |= t << (len * 4);
	}
	return res;
}

u8 *_x_to_u8_buffer(const s8 *hex){
	u32 len = strlen(hex);
	if(len % 2 != 0) return NULL;	// (add sanity check in caller)
	
	s8 xtmp[3] = {0, 0, 0};
	u8 *res = (u8 *)malloc(sizeof(u8) * len);
	u8 *ptr = res;
	while(len--){
		xtmp[0] = *hex++; xtmp[1] = *hex++;
		*ptr++ = (u8) _x_to_u64(xtmp);
	}
	return res;
}

void bn_print(const char *name, const u8 *a, const short n, const short b){
	printf("%s", name);
	for(uint i = 0; i < n; i++) printf("%02x", a[i]);

	if(b == 1) printf("\n");
}

static const u8 inv256[0x80] = {
	0x01, 0xab, 0xcd, 0xb7, 0x39, 0xa3, 0xc5, 0xef,
	0xf1, 0x1b, 0x3d, 0xa7, 0x29, 0x13, 0x35, 0xdf,
	0xe1, 0x8b, 0xad, 0x97, 0x19, 0x83, 0xa5, 0xcf,
	0xd1, 0xfb, 0x1d, 0x87, 0x09, 0xf3, 0x15, 0xbf,
	0xc1, 0x6b, 0x8d, 0x77, 0xf9, 0x63, 0x85, 0xaf,
	0xb1, 0xdb, 0xfd, 0x67, 0xe9, 0xd3, 0xf5, 0x9f,
	0xa1, 0x4b, 0x6d, 0x57, 0xd9, 0x43, 0x65, 0x8f,
	0x91, 0xbb, 0xdd, 0x47, 0xc9, 0xb3, 0xd5, 0x7f,
	0x81, 0x2b, 0x4d, 0x37, 0xb9, 0x23, 0x45, 0x6f,
	0x71, 0x9b, 0xbd, 0x27, 0xa9, 0x93, 0xb5, 0x5f,
	0x61, 0x0b, 0x2d, 0x17, 0x99, 0x03, 0x25, 0x4f,
	0x51, 0x7b, 0x9d, 0x07, 0x89, 0x73, 0x95, 0x3f,
	0x41, 0xeb, 0x0d, 0xf7, 0x79, 0xe3, 0x05, 0x2f,
	0x31, 0x5b, 0x7d, 0xe7, 0x69, 0x53, 0x75, 0x1f,
	0x21, 0xcb, 0xed, 0xd7, 0x59, 0xc3, 0xe5, 0x0f,
	0x11, 0x3b, 0x5d, 0xc7, 0x49, 0x33, 0x55, 0xff,
};

int main(int argc, char **argv)
{
	/* OpenCL support */
	printf("Check OpenCL environtment\n");
	
	cl_platform_id platid;
	cl_device_id devid;
	cl_int res;
	size_t param;
	
	/* Query OpenCL, get some information about the returned device */
	clGetPlatformIDs(1u, &platid, NULL);
	clGetDeviceIDs(platid, CL_DEVICE_TYPE_ALL, 1, &devid, NULL);

	cl_char vendor_name[1024] = {0};
	cl_char device_name[1024] = {0};
	clGetDeviceInfo(devid, CL_DEVICE_VENDOR, sizeof(vendor_name), vendor_name, NULL);
	clGetDeviceInfo(devid, CL_DEVICE_NAME,   sizeof(device_name), device_name, NULL);
	printf("Connecting to OpenCL device:\t%s %s\n", vendor_name, device_name);
	
	clGetDeviceInfo(devid, CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(cl_uint), &param, NULL);
	printf("CL_DEVICE_MAX_COMPUTE_UNITS\t%d\n", param);
	
	clGetDeviceInfo(devid, CL_DEVICE_MAX_WORK_GROUP_SIZE, sizeof(size_t), &param, NULL);
	printf("CL_DEVICE_MAX_WORK_GROUP_SIZE\t%u\n", param);

	clGetDeviceInfo(devid, CL_DEVICE_LOCAL_MEM_SIZE, sizeof(cl_ulong), &param, NULL);
	printf("CL_DEVICE_LOCAL_MEM_SIZE\t%ub\n", param);

	/* Check if kernel source exists, we compile argv[1] passed kernel */
	if(argv[1] == NULL) { printf("\nUsage: %s kernel_source.cl kernel_function\n", argv[0]); exit(1); }

	char *kernel_source;
	if(load_program_source(argv[1], &kernel_source)) return 1;
	
	printf("Building from OpenCL source: \t%s\n", argv[1]);
	printf("Compile/query OpenCL_program:\t%s\n", argv[2]);
	
	/* Create context and kernel program */
	cl_context context = 	clCreateContext(0, 1, &devid, NULL, NULL, NULL);
	cl_program pro = 	clCreateProgramWithSource(context, 1, (const char **)&kernel_source, NULL, NULL);
	res = 			clBuildProgram(pro, 1, &devid, "-cl-fast-relaxed-math", NULL, NULL);

	if(res != CL_SUCCESS){
		printf("clBuildProgram failed: %d\n", res); char buf[0x10000];
		clGetProgramBuildInfo(pro, devid, CL_PROGRAM_BUILD_LOG, 0x10000, buf, NULL);
		printf("\n%s\n", buf); return(-1); }

	cl_kernel kernelobj = clCreateKernel(pro, argv[2], &res); 	check_return(res);
	
	/* Get the maximum work-group size for executing the kernel on the device */
	size_t global, local;
	res = clGetKernelWorkGroupInfo(kernelobj, devid, CL_KERNEL_WORK_GROUP_SIZE, sizeof(int), &local, NULL);		check_return(res);
	printf("CL_KERNEL_WORK_GROUP_SIZE\t%u\n", local);
	
	res = clGetKernelWorkGroupInfo(kernelobj, devid, CL_KERNEL_LOCAL_MEM_SIZE, sizeof(cl_ulong), &param, NULL);	check_return(res);
	printf("CL_KERNEL_LOCAL_MEM_SIZE\t%ub\n", param);
	
	cl_command_queue cmd_queue = clCreateCommandQueue(context, devid, CL_QUEUE_PROFILING_ENABLE, NULL);
	if(cmd_queue == NULL) { printf("Compute device setup failed\n"); return(-1); }

	local = 4;
	int n = 2 * local;	//num_group * local workgroup size 
	global = n;
	
	int	num_groups=		global / local,
		allocated_local=	sizeof(data) * local + 
					sizeof(debug) * local;

	data *DP __attribute__ ((aligned(16)));
	DP = calloc(n, sizeof(data) *1);

	debug *dbg __attribute__ ((aligned(16)));
	dbg = calloc(n, sizeof(debug));
	
	printf("global:%d, local:%d, (should be):\t%d groups\n", global, local, num_groups);
	printf("structs size: %db, %db, %db\n", sizeof(data), sizeof(Elliptic_Curve), sizeof(inv256));
	printf("sets:%d, total of %db needed, allocated _local: %db\n", n, n * sizeof(cl_uint4) *5 *4, allocated_local);

	cl_mem	cl_DP, cl_EC, cl_INV, DEBUG;
	cl_DP = clCreateBuffer(context, CL_MEM_ALLOC_HOST_PTR, n * sizeof(data), NULL, &res);					check_return(res);				
	cl_EC = clCreateBuffer(context, CL_MEM_ALLOC_HOST_PTR | CL_MEM_READ_ONLY,  1 * sizeof(Elliptic_Curve), NULL, &res);	check_return(res);	//_constant address space
	cl_INV= clCreateBuffer(context, CL_MEM_ALLOC_HOST_PTR | CL_MEM_READ_ONLY,  1 * sizeof(u8) * 0x80, NULL, &res);		check_return(res);
	DEBUG = clCreateBuffer(context, CL_MEM_ALLOC_HOST_PTR | CL_MEM_WRITE_ONLY, n * sizeof(debug), NULL, &res);		check_return(res);
	
	Elliptic_Curve EC;
	/*	
		Curve domain parameters, (test vectors)
		-------------------------------------------------------------------------------------
		p:	c1c627e1638fdc8e24299bb041e4e23af4bb5427		is prime
		a:	c1c627e1638fdc8e24299bb041e4e23af4bb5424		divisor g = 62980
		b:	877a6d84155a1de374b72d9f9d93b36bb563b2ab		divisor g = 227169643
		Gx: 	010aff82b3ac72569ae645af3b527be133442131		divisor g = 32209245
		Gy: 	46b8ec1e6d71e5ecb549614887d57a287df573cc		divisor g = 972			
	*/	
	u8 *t;
	t = _x_to_u8_buffer("c1c627e1638fdc8e24299bb041e4e23af4bb5427");	memcpy(EC.p, t, 20);
	t = _x_to_u8_buffer("c1c627e1638fdc8e24299bb041e4e23af4bb5424");	memcpy(EC.a, t, 20);
	t = _x_to_u8_buffer("877a6d84155a1de374b72d9f9d93b36bb563b2ab");	memcpy(EC.b, t, 20);
	t = _x_to_u8_buffer("010aff82b3ac72569ae645af3b527be133442131");	memcpy(EC.G.x, t, 20);
	t = _x_to_u8_buffer("46b8ec1e6d71e5ecb549614887d57a287df573cc");	memcpy(EC.G.y, t, 20);
	free(t);

	res = clEnqueueWriteBuffer(cmd_queue, cl_EC,  CL_TRUE, 0, 1 * sizeof(Elliptic_Curve), &EC, 0, NULL, NULL);	check_return(res);
	res = clEnqueueWriteBuffer(cmd_queue, cl_INV, CL_TRUE, 0, 1 * sizeof(u8) * 0x80, &inv256, 0, NULL, NULL);	check_return(res);


	res = clSetKernelArg(kernelobj, 0, sizeof(cl_mem), &cl_DP);		/* output buffer */
	res|= clSetKernelArg(kernelobj, 1, sizeof(data) * local *1, NULL);	//allocate space for __local in kernel (just this!) one * localsize
	res|= clSetKernelArg(kernelobj, 2, sizeof(cl_mem), &cl_EC);
	res|= clSetKernelArg(kernelobj, 3, sizeof(cl_mem), &cl_INV);	
	res|= clSetKernelArg(kernelobj, 4, sizeof(debug) * local *1, NULL);	//allocate space for __local in kernel (just this!) one * localsize
	res|= clSetKernelArg(kernelobj, 5, sizeof(cl_mem), &DEBUG);		//this used to debug kernel output
	check_return(res);

	printf("n:%d, total of %db needed, allocated _local: %db\n", n, n * sizeof(debug), allocated_local);	
	
	cl_event NDRangeEvent;
	cl_ulong start, end;
	
	/* Execute NDrange */	
	res = clEnqueueNDRangeKernel(cmd_queue, kernelobj, 1, NULL, &global, &local, 0, NULL, &NDRangeEvent);		check_return(res);
	
	printf("Read back, Mapping buffer:\t%db\n", n * sizeof(data));

	DP = clEnqueueMapBuffer(cmd_queue, cl_DP, CL_TRUE, CL_MAP_READ, 0, n * sizeof(data),  0, NULL, NULL, &res);	check_return(res);
	dbg =clEnqueueMapBuffer(cmd_queue, DEBUG, CL_TRUE, CL_MAP_READ, 0, n * sizeof(debug), 0, NULL, NULL, &res);	check_return(res);
	
	/* using clEnqueueReadBuffer template */
//	res = clEnqueueReadBuffer(cmd_queue, ST, CL_TRUE, 0, sets * sizeof(cl_uint8), dbg, 0, NULL, NULL);			check_return(res);
		
	clFlush(cmd_queue);
	clFinish(cmd_queue);

	/* get NDRange execution time with internal ocl profiler */
	res = clGetEventProfilingInfo(NDRangeEvent, CL_PROFILING_COMMAND_START, sizeof(cl_ulong), &start, NULL);
	res|= clGetEventProfilingInfo(NDRangeEvent, CL_PROFILING_COMMAND_END,   sizeof(cl_ulong), &end,   NULL);
	check_return(res);
	printf("kernel execution time:\t\t%.2f ms\n", (float) ((end - start) /1000000));			//relative to NDRange call
	//printf("number of computes/sec:\t%.2f\n", (float) global *4 /time_seconds);

	printf("i,\tgid\tlid0\tlsize0\tgid0/lsz0,\tgsz0,\tn_gr0,\tlid5,\toffset\n");
	for(int i = 0; i < global; i++) {
		if(
			i %1 == 0
		) {
			printf("%d \t", i);
			//printf("%u\t%u\t%u\t%u\t| %2u, %2u, %2u, %u\n", *p, *(p +1), *(p +2), *(p +3), *(p +4), *(p +5), *(p +6), *(p +7));
			printf("%u\t%u\t%u\t%u\t| %2u, %2u, %2u, %u\n", 
				dbg[i].data[0], dbg[i].data[1], dbg[i].data[2], dbg[i].data[3],
				dbg[i].data[4], dbg[i].data[5], dbg[i].data[6], dbg[i].data[7]);
				
			//printf("%d %d\n", P[i].dig, P[i].c);
			bn_print("", DP[i].P.x, 20, 0); bn_print(" ", DP[i].P.y, 20, 1);
		}
	}

	/* Release OpenCL stuff, free the rest */
	clReleaseMemObject(cl_DP);
	clReleaseMemObject(cl_INV);
	clReleaseMemObject(cl_EC);
	clReleaseMemObject(DEBUG);
	clReleaseKernel(kernelobj);
	clReleaseProgram(pro);
	clReleaseCommandQueue(cmd_queue);
	clReleaseContext(context);
	
	free(kernel_source);
	
	puts("Done!");
	return 0;
}
