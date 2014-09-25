/* Header to make Clang compatible with OpenCL */
#define __global __attribute__((address_space(1)))

//int get_global_id(int index);

typedef unsigned char u8;
typedef unsigned int u32;

//typedef cl_uchar u8;
//typedef cl_uint u32;

struct point{
	u8 x[20];
	u8 y[20];
	u8 pad[3];
	u8 c;
	u32 dig;
};

struct Elliptic_Curve {
	u8 p[20];		//s[20]
	u8 a[20];		//t[20]
	u8 b[20];		//u[20]
	struct point G;		//ppx[20], ppy[20]
};				//pad[3], u8 c, u32 dig

int bn_is_zero(
	__local const u8 *d, const u32 n){
	for(u8 i = 0; i < n; i++)
		if (d[i] != 0) return 0;

	return 1;
}

/* a _kernel user_zerofill sample */
void bn_zero(__local u8 *d, const u32 n){
	for(u8 i = 0; i < n; i++) d[i] = 0;
}

/* a _kernel user_memcpy sample */
void bn_copy(__local u8 *d, const u8 *a, const u32 n){
	for(u8 i = 0; i < n; i++) d[i] = a[i];
}

/* a _kernel user_memcmp sample */
int bn_compare(__local const u8 *a, __constant const u8 *b, const u32 n){
	for(u8 i = 0; i < n; i++){
		if(a[i] < b[i]) return -1;
		if(a[i] > b[i]) return 1;
	}
	return 0;
}

u8 bn_add_1(__local u8 *d, __local const u8 *a, __local const u8 *b, const u32 n){
	u32 dig;
	u8 c = 0;
	for(u8 i = n - 1; i < n; i--){
		dig = a[i] + b[i] + c;
		c = dig >> 8;
		d[i] = dig;
	}
	return c;
}

u8 bn_sub_1(__local u8 *d, __local const u8 *a, __constant const u8 *b, const u32 n){
	u32 dig;
	u8 c = 1;
	for(u8 i = n - 1; i < n; i--){
		dig = a[i] + 255 - b[i] + c;
		c = dig >> 8;
		d[i] = dig;
	}
	return 1 - c;
}

void bn_reduce(__local u8 *d, __constant const u8 *N, const u32 n){
	if(bn_compare(d, N, n) >= 0)
		bn_sub_1(d, d, N, n);
}

void bn_to_mon(__local u8 *d, __constant const u8 *N, const u32 n){
	for(u8 i = 0; i < 8*n; i++){		//bn_add(d, d, d, N, n);
		if(bn_add_1(d, d, d, n)) bn_sub_1(d, d, N, n);
		bn_reduce(d, N, n);
	}
}

void bn_mon_muladd_dig(__local u8 *d, const u8 *a, const u8 b, __constant const u8 *N, const u32 n){
	u32 dig;
	u8 c;// = -(d[n-1] + a[n-1] *b) * inv256[N[n-1] /2];

	dig = d[n-1] + a[n-1] *b + N[n-1] *c;
	dig >>= 8;

	for(u8 i = n - 2; i < n; i--){
		dig += d[i] + a[i] *b + N[i] *c;
		d[i+1] = dig;
		dig >>= 8;
	}

	d[0] = dig;
	dig >>= 8;

	if(dig) bn_sub_1(d, d, N, n);

	bn_reduce(d, N, n);
}

void bn_mon_mul(__local u8 *d, __local const u8 *a, __local const u8 *b, __constant const u8 *N, const u32 n){
	u8 t[512];
//	bn_zero(t, n);

	for(u8 i = n -1; i < n; i--)
//		bn_mon_muladd_dig(t, a, b[i], N, n);

	bn_copy(d, t, n);
}

void point_double(__local  struct point * restrict r, __constant struct point * restrict G)
{	
	if(bn_is_zero(r->y, 20)){
		bn_zero(r->x, 20), bn_zero(r->y, 20); return; }
		
	__local struct Elliptic_Curve lC;	// -> CL_KERNEL_LOCAL_MEM_SIZE 108b
/*
struct Elliptic_Curve {
	u8 p[20];		//s[20]
	u8 a[20];		//t[20]
	u8 b[20];		//u[20]
	struct point G;		//ppx[20], ppy[20]
};				//pad[3], u8 c, u32 dig  (1*3 + 1 + 4) -> CL_KERNEL_LOCAL_MEM_SIZE 108b
*/
	lC.G = *r;
	
//	u8	s[20], t[20], 
//		*px = pp.x, *py = pp.y;
//		*rx = r->x, *ry = r->y;

// t = px*px
	bn_mon_mul(lC.a, lC.G.x, lC.G.x, 1, 20);//512
	
// s = 2*px*px				bn_add(s, t, t, EC.p, 20);	//u32 dig, u8 c
	if(bn_add_1(lC.p, lC.a, lC.a, 20))
		bn_sub_1(lC.p, lC.p, 1, 20);
	bn_reduce(lC.p, 1, 20);
// s = 3*px*px				bn_add(s, s, t, EC.p, 20);
	if(bn_add_1(lC.p, lC.p, lC.a, 20))
		bn_sub_1(lC.p, lC.p, 1, 20);
	bn_reduce(lC.p, 1, 20);
// s = 3*px*px + a			bn_add(s, s, EC.a, EC.p, 20);	//const ec_a is needed here
	if(bn_add_1(lC.p, lC.p, 3, 20)) 	//EC.a
		bn_sub_1(lC.p, lC.p, 1, 20);
	bn_reduce(lC.p, 1, 20);
// t = 2*py				bn_add(t, py, py, EC.p, 20);
	if(bn_add_1(lC.a, lC.G.y, lC.G.y, 20))
		bn_sub_1(lC.a, lC.a, 1, 20);
	bn_reduce(lC.a, 1, 20);
// s = (3*px*px+a)/(2*py)
	bn_mon_mul(lC.p, lC.p, lC.a, 1, 20);	//512
// rx = s*s
	bn_mon_mul(r->x, lC.p, lC.p, 1, 20);	//512
// t = 2*px				bn_add(t, px, px, EC.p, 20);
	if(bn_add_1(lC.a, lC.G.x, lC.G.x, 20)) 
		bn_sub_1(lC.a, lC.a, 1, 20);
	bn_reduce(lC.a, 1, 20);	
// rx = s*s - 2*px			bn_sub(rx, rx, t, EC.p, 20);
	if(bn_sub_1(r->x, r->x, 2, 20)) 	//lC.a = const?!
		bn_add_1(r->x, r->x, 1, 20);
// t = -(rx-px)				bn_sub(t, px, rx, EC.p, 20);
	if(bn_sub_1(lC.a, lC.G.x, 2, 20))	//lC.G.x
		bn_add_1(lC.a, lC.a, 1, 20);
// ry = -s*(rx-px)
	bn_mon_mul(r->y, lC.p, lC.a, 1, 20);	//512
// ry = -s*(rx-px) - py			bn_sub(ry, ry, py, EC.p, 20);	//u32 dig, u8 c
	if(bn_sub_1(r->y, r->y, 2, 20)) //lC.G.y
		bn_add_1(r->y, r->y, 1, 20); 
}	//out rx, ry

void point_add(__local  struct point * restrict r, __constant struct point * restrict G)
{}

#define WORK_GROUP_SIZE 4	//preferred size
__kernel __attribute__ ((reqd_work_group_size (WORK_GROUP_SIZE, 1, 1)))
void point_mul(
	__global struct point *P,		//to save output points
	__local  struct point * restrict lP,	//a _local context, CL_KERNEL_LOCAL_MEM_SIZE query
	__global u8 *k,				//integer, 160bit
	__constant struct point * restrict G,	//generator
	__local	 uint8 * restrict l8,		//to save debug output, CL_KERNEL_LOCAL_MEM_SIZE query
	__global uint8 * restrict out )		//to save debug output
{
	const int gid =		get_global_id(0),	lid =		get_local_id(0);
	const int gid5 =	gid *5,			lid5 =		lid *5;
	const int local_size =	get_local_size(0),	offset =	local_size * get_group_id(0);
	const int stride5 =	lid5 + (offset *5);

	__local struct point 
		*p = lP + lid;
	
	/* ocl needs to initialize: zerofill sizeof(point) to 0 */
	bn_zero(p, 48);

	for(u8 i = 0; i < 21; i++)
		for(u8 mask = 0x80; mask != 0; mask >>= 1){
			point_double(p, G);
			if((k[i] & mask) != 0) point_add(p, G);
		}	
	
	/* save debug output */	
	out[offset + lid] =
	/* we can use also	 l8[lid] =
	   or			 out[gid] =
	   here... */
	(uint8) {
		gid,			lid,
		get_local_size(0),	get_global_size(0),	//get_global_id(0) / get_local_size(0),    // this == num_groups
		get_num_groups(0),	get_group_id(0),	//get_local_id(0) %2
		offset,			stride5
	};
	
	*p = *G;		//copy 48bytes _const to _local
	bn_zero(p->pad, 8);	//zerofill struct padding
	
	barrier(CLK_LOCAL_MEM_FENCE);
	
	/* Copy to output buffers, _global P[gid] = _local *p */
	P[offset + lid] = *p;
}
