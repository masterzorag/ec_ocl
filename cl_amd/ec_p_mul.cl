/*
	2014, masterzorag@gmail.com
	
   ocl: we need to pass an auxiliary local_ctx across calls
   u32 dig, u8 c, d[20];
   u8 s[20], t[20], u[20];
     
   bn_add, bn_sub,		dig, c
   bn_mon_mul			dig, c, d[20]
   bn_mon_inv			dig, c, d[20], v
*/

typedef unsigned char u8;
typedef unsigned int u32;

#define LEN 20		// fix bitlen / sizeof(u8)

struct data{		// 176b
	u8 x[20];
	u8 y[20];
				
	u8 s[20];	//
	u8 t[20];	//16
	u8 u[20];	//

	u8 v[20];	// for inv

	u8 d[20];	//+ mul
	u8 k[21];
	u8 c;		//+ all
	u8 pad[8];	//we can store NDRange debug
	u32 dig;	//+ all
}
__attribute__((aligned(16)));	

/*
	32768b / 176b = 186 (max wi in a group)
	186 % 16 = 10 (!= 0, so:
	176 * 176b = 30976b needed in a wg
	32768 - 30976 = 1792b unused 
*/

struct point{
	u8 x[20];
	u8 y[20];
};

struct Elliptic_Curve{
	u8 p[20];
	u8 a[20];
	u8 b[20];
	struct point G;		//use Gx, Gy instead
	u8 U[20], V[20];	//per_curve_inv constants
	u32 pad;
}
__attribute__((aligned(16)));	//144b

typedef struct{
	u32 data[8];
} debug;

int bn_is_zero(__local const u8 *d){
	for(u8 i = 0; i < LEN; i++)
		if (d[i] != 0) return 0;

	return 1;
}

/* a _kernel user_zerofill sample */
void bn_zero(__local u8 *d){
	for(u8 i = 0; i < LEN; i++) d[i] = 0;
}

/* a _kernel user_memcpy sample */
void bn_copy(__local u8 *d, __local const u8 *a){
	for(u8 i = 0; i < LEN; i++) d[i] = a[i];
}

/* a _kernel user_memcmp sample */
int bn_compare(__local const u8 *a, __constant const u8 *b){
	for(u8 i = 0; i < LEN; i++){
		if(a[i] < b[i]) return -1;
		if(a[i] > b[i]) return 1;
	}
	return 0;
}

void bn_add(
	__local u8 *d,				//io
	__local const u8 *a, 
	__local const u8 *b,			//in point_add is also qx
	__constant const u8 *N,			//mod
	__local u8 *aux)		//unused
{
	u32 dig; u8 c;			//needs aux_local, aux.d[LEN] unused
	
	c = 0; for(u8 i = LEN -1; i < LEN; i--){ dig = a[i] + b[i] + c; c = dig >> 8; d[i] = dig; }				//-	c = bn_add_1(d, a, b, n);
	if(c){
		c = 1; for(u8 i = LEN -1; i < LEN; i--){ dig = d[i] + 255 - N[i] + c; c = dig >> 8; d[i] = dig; }	//-	bn_sub_1(d, d, N, n);
	}
	
	if(bn_compare(d, N) >= 0){																//-	bn_reduce(d, N, n);	
		c = 1; for(u8 i = LEN -1; i < LEN; i--){ dig = d[i] + 255 - N[i] + c; c = dig >> 8; d[i] = dig; }	//-	bn_sub_1(d, d, N, n);
	}
}

void bn_sub(
	__local u8 *d,				//io
	const u8 *a,			//in point_add is also qx, qy 
	__local const u8 *b,
	__constant const u8 *N)			//mod
//	struct local *aux)		//unused
{
	u32 dig; u8 c;			//needs aux_local, aux.d[20] unused
	
	c = 1; for(u8 i = LEN -1; i < LEN; i--){ dig = a[i] + 255 - b[i] + c; c = dig >> 8; d[i] = dig; }		//-	c = bn_sub_1(d, a, b, n);
	c = 1 - c;
	if(c){
		c = 0; for(u8 i = LEN -1; i < LEN; i--){ dig = d[i] + N[i] + c;	c = dig >> 8; d[i] = dig; }			//-	bn_add_1(d, d, N, n);
	}
}

void bn_mon_mul(
	__local u8 *io,
	__local const u8 *a,
	__local const u8 *b, 
	__constant const u8 *N,		//mod
	__constant const u8 *inv256,
	__local u8 *d		//*aux_local
	//, c; u32 dig;		// 20 + 1 + 4 = 25b
){
	u8 c;		//needs a temp buffer !!
	u32 dig;
	
	bn_zero(d);

	for(u8 i = LEN -1; i < LEN; i--){		
		c =   -(d[LEN -1] + a[LEN -1] *b[i]) * inv256[N[LEN -1] /2];
		dig = d[LEN -1] + a[LEN -1] *b[i] + N[LEN -1] *c; dig >>= 8;
	
		for(u8 j = LEN -2; j < LEN; j--){ dig += d[j] + a[j] *b[i] + N[j] *c; d[j+1] = dig; dig >>= 8; }	
		d[0] = dig; dig >>= 8;
	
		if(dig){
			c = 1; for(u8 i = LEN -1; i < LEN; i--){ dig = d[i] + 255 - N[i] + c; c = dig >> 8; d[i] = dig; }	//-	bn_sub_1(d, d, N, n);
		}

		if(bn_compare(d, N) >= 0) {																					//-	bn_reduce(d, N, 20);
			c = 1; for(u8 i = LEN -1; i < LEN; i--){ dig = d[i] + 255 - N[i] + c; c = dig >> 8; d[i] = dig; }	//-	bn_sub_1(d, d, N, n);
		}
	}
	bn_copy(io, d);
}

void bn_mon_inv(
	__local u8 *d,			// d = 1/a mod N
	__local const u8 *a,				
	__constant const u8 *N,
	__constant const u8 *inv256,
	__constant const u8 *U,		// precomputed per_curve_constant
	__constant const u8 *V,		// precomputed per_curve_constant
	__local u8 *v,
	__local u8 *aux			// u8 d[20], c; u32 dig;
){
//	bn_copy(d, V);			//1 copy from _const to loc shall be: v = V in advance
	for(u8 i = 0; i < LEN; i++) d[i] = V[i];

/*	now do stuff with: d, v, use also U, a		
	as seen below, v can starts initialized per_curve_constant, 
	saving a bn_mon_mul
*/	

	for(u8 i = 0; i < LEN; i++){
		for(u8 mask = 0x80; mask != 0; mask >>= 1){
			bn_mon_mul(v, d, d, N, inv256, aux);		// +aux, v = d * d
					
			/* v can starts initialized per_curve_constant !!!
			if(mask == 0x80 && i == 0) bn_print("v", v, 20);*/
		
/* U */			if((U[i] & mask) != 0)				// per_curve_constant	
/* a */				bn_mon_mul(d, v, a, N, inv256, aux);		// d = v * a
			else
				bn_copy(d, v);					// d = v
		}
	}
}	// out d

void point_double(
	__local struct data *r,
	__constant struct Elliptic_Curve *EC,
	__constant const u8 *inv256 )
{	
	if(bn_is_zero(r->y)){
		bn_zero(r->x), bn_zero(r->y);	return;
	}

// t = px*px
	bn_mon_mul(r->t, r->x, r->x, EC->p, inv256, r->d);	// +aux
// s = 2*px*px
	bn_add(r->s, r->t, r->t, EC->p, 0);			// +dig, c
// s = 3*px*px
	bn_add(r->s, r->s, r->t, EC->p, 0);
// s = 3*px*px + a
	//bn_copy(r->t, EC->a);				//const ec_a is needed here, use (tu)
	bn_add(r->s, r->s, EC->a, EC->p, 0);
// t = 2*py
	bn_add(r->t, r->y, r->y, EC->p, 0);	
// t = 1/(2*py)
	bn_copy(r->u, r->t);
	bn_mon_inv(r->t, r->u, EC->p, inv256, EC->U, EC->V, r->v, r->d);	// +U, V, (v)	
// s = (3*px*px+a)/(2*py)
	bn_mon_mul(r->s, r->s, r->t, EC->p, inv256, r->d);
// rx = s*s							
	bn_copy(r->u, r->x);				// backup old rx now ! u = rx
	bn_mon_mul(r->x, r->s, r->s, EC->p, inv256, r->d);	// +aux
// t = 2*px							reuse backed up value: u = rx
	bn_add(r->t, r->u, r->u, EC->p, 0);
// rx = s*s - 2*px
	bn_sub(r->x, r->x, r->t, EC->p);		//r->x =
	
// t = -(rx-px)						reuse backed up value: u = rx
	bn_sub(r->t, r->u, r->x, EC->p);
// ry = -s*(rx-px)
	bn_copy(r->u, r->y);				// backup old ry now ! u = ry
	bn_mon_mul(r->y, r->s, r->t, EC->p, inv256, r->d);	// +aux
// ry = -s*(rx-px) - py					reuse backed up value: u = ry
	bn_sub(r->y, r->y, r->u, EC->p);		//r->y =
	
}

void point_add(
	__local struct data *r,
	__constant struct Elliptic_Curve *EC,
	__constant const u8 *inv256 )
{
	if(bn_is_zero(r->x)
	&& bn_is_zero(r->y)){			//*r = *q;		
//		bn_copy(r->x, EC->G.x);		// bn_copy(ry, qy);
		for(u8 i = 0; i < LEN; i++) r->x[i] = EC->G.x[i];
//		bn_copy(r->y, EC->G.y);
		for(u8 i = 0; i < LEN; i++) r->y[i] = EC->G.y[i];
		return; }
/*
	if(bn_is_zero(EC->G.x)			//point_is_zero(q) ??, G != 0 !!
	&& bn_is_zero(EC->G.y)) return;
*/			
// u = qx-px
	bn_sub(r->u, EC->G.x, r->x, EC->p);		//u32 dig, u8 c 

	if(bn_is_zero(r->u)){
	// u = qy-py
		bn_sub(r->u, EC->G.y, r->y, EC->p);	// subs const qy !!
		
		if(bn_is_zero(r->u)){
			point_double(r, EC, inv256);
		}else{
			bn_zero(r->x); bn_zero(r->y); }

		return;
	}

// t = 1/(qx-px)
	bn_mon_inv(r->t, r->u, EC->p, inv256, EC->U, EC->V, r->v, r->d);	// +U, V, (v)
// u = qy-py
	bn_sub(r->u, EC->G.y, r->y, EC->p);		// subs const qy !!
	
// s = (qy-py)/(qx-px)
	bn_mon_mul(r->s, r->t, r->u, EC->p, inv256, r->d);		// +aux
	
// rx = s*s
	bn_copy(r->u, r->x);				// backup old rx now ! u = rx
	bn_mon_mul(r->x, r->s, r->s, EC->p, inv256, r->d);	// +aux

// t = px+qx
	bn_add(r->t, r->u, EC->G.x, EC->p, 0);		// adds const qx !!
// rx = s*s - (px+qx)
	bn_sub(r->x, r->x, r->t, EC->p);

// t = -(rx-px)						reuse backed up value: u = rx
	bn_sub(r->t, r->u, r->x, EC->p);
	
// ry = -s*(rx-px)
	bn_copy(r->u, r->y);				// backup old ry now ! u = ry
	bn_mon_mul(r->y, r->s, r->t, EC->p, inv256, r->d);	// +aux
	
// ry = -s*(rx-px) - py					reuse backed up value: u = ry
	bn_sub(r->y, r->y, r->u, EC->p);
}

#define WORK_GROUP_SIZE 4	// preferred size
__kernel __attribute__((reqd_work_group_size (WORK_GROUP_SIZE, 1, 1)))
void point_mul(
	__global struct data *dP,	// io data
	__local struct data *lP,	// a _local data, CL_KERNEL_LOCAL_MEM_SIZE query
	__constant struct Elliptic_Curve *EC,
	__constant u8 *inv256,
	__local debug *l8,		//to save debug output, CL_KERNEL_LOCAL_MEM_SIZE query
	__global debug *dbg )		//to save debug output
{
	const int gid =		get_global_id(0),	lid =		get_local_id(0);
	const int local_size =	get_local_size(0),	offset =	local_size * get_group_id(0);
	const int stride5 =	(lid + offset) *5;

	__local struct data *p = &lP[lid];
	
	lP[lid] = dP[offset + lid];
	barrier(CLK_LOCAL_MEM_FENCE);

	/* clean points */
	bn_zero(p->x), bn_zero(p->y);
	
	//lP[lid] = dP[offset + lid];
//	*p->k = dP[offset + lid].k;
//	bn_copy(p->k + 1, dP[offset + lid].k);	
	
	for(u8 i = 0; i < 21; i++)
		for(u8 mask = 0x80; mask != 0; mask >>= 1){			//840.00 ms total
			point_double(p, EC, inv256);			//533.00 ms	
			if((p->k[i] & mask) != 0) point_add(p, EC, inv256);	//579.00 ms
		}
			
	/* 	save debug output, we can use also:
		dbg[gid], or directly dbg[offset + lid]
	*/
	l8[lid].data[0] = gid;			l8[lid].data[1] = lid;
	l8[lid].data[2] = get_local_size(0);	l8[lid].data[3] = get_global_size(0);
	l8[lid].data[4] = get_num_groups(0);	l8[lid].data[5] = get_group_id(0);
	l8[lid].data[6] = offset;		l8[lid].data[7] = stride5;	
	
	// testing constant address space for consistency //
	//*p = EC->G;		//all workiterm exports generator, copy 40bytes _const to _local 
	//p->x[10] = inv256[120];
	
	lP[lid].pad[0] = gid;			lP[lid].pad[1] = lid;
	lP[lid].pad[2] = get_local_size(0);	lP[lid].pad[3] = get_global_size(0);
	lP[lid].pad[4] = get_num_groups(0);	lP[lid].pad[5] = get_group_id(0);
	lP[lid].pad[6] = offset;		lP[lid].pad[7] = stride5;

//	lP[lid].x[10] = inv256[120];
//	lP[lid].k[1] = inv256[120];
/*
	bn_zero(p->x);
	bn_zero(p->y);
*/	
	barrier(CLK_LOCAL_MEM_FENCE);
		
	/* Copy to output buffers, _global P[gid] = _local *p */

/*	bn_copy(dP[offset + lid].x, lP[lid].x);		//bn_copy(dP[offset + lid].x, &lP[lid]);
//	dP[offset + lid].x = p->x;
	bn_copy(dP[offset + lid].y, lP[lid].y);
*/	
	bn_copy(dP[offset + lid].x, p->x);
	bn_copy(dP[offset + lid].y, p->y);
	bn_copy(dP[offset + lid].pad, p->pad);	// save debug NDRange variables
//	dP[offset + lid] = lP[lid];		// or copy back whole datatype!
	
//	bn_copy(dP[offset + lid].k +1, EC->G.x);
//	bn_copy(dP[offset + lid].pad, lP[lid].pad);

	dbg[offset + lid] = l8[lid];		// unneeded by using u8 pad[8]
}