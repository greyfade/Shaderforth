:globals
	@vec3 uniform =iResolution
	@float uniform =iGlobalTime
	@vec3 uniform =iMouse
;

: rotationmat ( axis:vec3 angle:float -> mat4 )
	axis normalize =axis
	angle sin =s
	angle cos =c
	1.0 c - =>oc

	[
		oc axis .x * axis .x * c +           , oc axis .x * axis .y * axis .z s * - , oc axis .z * axis .x * axis .y s * + , 0.0
		oc axis .x * axis .y * axis .z s * + , oc axis .y * axis .y * c +           , oc axis .y * axis .z * axis .x s * - , 0.0
		oc axis .z * axis .x * axis .y s * - , oc axis .y * axis .z * axis .x s * + , oc axis .z * axis .z * c +           , 0.0
		0.0                                  , 0.0                                  , 0.0                                  , 1.0
	]m
;

:m res-scale iResolution .xy / 0.5 - 2.0 * [ 1.0 iResolution .y.x / ]v * ;
:m mousepos iMouse .xy res-scale negate ;
:m clickpos iMouse .zw res-scale negate ;

:m rotate ( p axis angle ) [ p 1.0 ]v axis angle rotationmat * .xyz ;

:m sphere ( p s ) p length s - ;
:m torus ( p t ) [ p .xy length t .x - p .z ]v length t .y - ;
: box ( p:vec3 b:vec3 -> float )
	p abs b - =d
	d .x.y.z max max 0.0 min
	d 0.0 max length +
;
:m plane ( p n ) p n .xyz dot n .w + ;

:m union \min ;
:m hitunion \{ ( $a $b ) a b a .distance b .distance < select } ;
:m subtract \{ ( d1 d2 ) d1 negate d2 max } ;
:m intersect \max ;
:m repeat ( block p c ) p c mod 0.5 c * - *block ;

:m time iGlobalTime ;

:m tx ( p t ) p [ t   0.0 0.0 ]v + ;
:m ty ( p t ) p [ 0.0 t   0.0 ]v + ;
:m tz ( p t ) p [ 0.0 0.0 t   ]v + ;

:struct hit
	@float =distance
	@int =material
;

:m trotate [ 0.4 1.1 1.7 ]v time rotate ;

: scene ( p:vec3 -> hit )
	p 5.0 tz =p

	[
		[ p [ time sin 1.8 * 0.0 3.0 ]v + [ 2.0 2.0 0.1 ]v box 0 ] hit
		[ p trotate [ 0.2 0.5 0.4 ]v + [ 0.5 0.2 ]v torus 1 ] hit
		[ p trotate [ 0.2 0.5 0.4 time sin 2.0 * + ]v + 0.25 sphere 2 ] hit
	] hitunion
;

:struct material
	@vec3 =color
	@float =ambient
	@float =diffuse
	@float =specular
	@float =reflection
	@float =refraction
;

: get-material ( id:int -> material )
	[
		0 [ [ 1.0 1.0 1.0 ]v 0.0 0.3 10.0 -1.0 0.0 ] material
		1 [ [ 1.0 0.0 0.0 ]v 0.2 0.8 30.0 0.9 0.0 ] material
		2 [ [ 0.0 1.0 0.0 ]v 0.2 0.7 30.0 1.0 0.0 ] material
		  [ [ 0.0 0.0 1.0 ]v 0.1 0.7 40.0 1.2 0.0 ] material
	] id choose
;

0.0001 =>eps

:m getnormal ( p )
	[
		p eps        tx scene .distance
		p eps negate tx scene .distance -
		p eps        ty scene .distance
		p eps negate ty scene .distance -
		p eps        tz scene .distance
		p eps negate tz scene .distance -
	]v normalize
;

gl_FragCoord .xy 2.0 * iResolution .xy - iResolution .y / =pos

3.0 =>focus
20.0 =>far

[ 0.0 0.0 5.0 ]v =cp
[ 0.0 0.0 0.0 ]v =>ct

ct cp - normalize =>cd
[ 0.0 0.5 0.0 ]v =cu
cd cu cross =>cs
cs pos .x * cu pos .y * + cd focus * + normalize =dir

cp =ray
0.0 =dist

[ 0.0 0.0 ]v =s
[ 0.0 0.0 0.0 ]v =c

[ far -1 ] hit =cur

10 =>iters
{
	float iters float / 1.0 swap - =level

	{
		ray scene =cur
		dist cur .distance + far min =dist
		ray dir cur .distance * + =ray

		{ break } cur .distance 0.01 < when
	} 50 times

	{
		ray getnormal =normal

		[ 0.0 8.0 0.0 ]v =>lightpos
		[ 1.0 1.0 1.0 ]v =>lightcolor
		lightpos ray - normalize =ivec
		ivec normal dot 0.0 max =incidence
		lightcolor incidence * =>diffuse
		0.1 =>ambient

		cur .material get-material =mat

		0.0 =specular
		{
			ivec cp + normalize normal dot
			0.0 max mat .specular pow
			lightpos ray - length / =specular
		} mat .specular 0.0 != incidence 0.0 > and when

		c mat .color diffuse mat .diffuse * ambient mat .ambient * + specular + * level mat .reflection pow * + =c

		{
			dir normal reflect normalize =dir
			ray =cp
			ray dir + =ray
			0.0 =dist
		} {
			break
		} mat .reflection 0.0 != if
	} {
		break
	} dist far < if
} iters times

[ c 1.0 ]v =gl_FragColor
