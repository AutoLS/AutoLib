#import "Math";

Vec2 :: struct($T: Type)
{
    x: T;
    y: T;
}

to_vector3 :: (v: Vector2) -> Vector3
{
    return .{v.x, v.y, 0};
}

perp :: (v: Vector2) -> Vector2
{
    return .{-v.y, v.x};
}

reverse_perp :: (v: Vector2) -> Vector2
{
    return .{v.y, -v.x};
}

radians :: (theta: float) -> float
{
	return (theta * (PI/180.0));
}

cross :: (a: Vector2, k: float) -> Vector2
{
    return .{-1 * a.y * k, a.x * k};
}

make_rotation_matrix :: (axis: Vector3, angle: float) -> Matrix4 
{
	q: Quaternion;
	set_from_axis_and_angle(*q, axis.x, axis.y, axis.z, angle);
	return rotation_matrix(Matrix4, q);
}

//NOTE: angle is in radians
make_model_matrix :: (position: Vector3, scale_v: Vector3, axis: Vector3 = .{}, angle: float = 0) -> Matrix4
{
    rotation := identity_of(Matrix4);
	if angle then rotation = make_rotation_matrix(axis, angle);
    
    model := scale(translate(identity_of(Matrix4), .{position.x, position.y, 0}) * rotation, .{scale_v.x, scale_v.y, 0});

    return model;
}

normalize :: (q: Quaternion) -> Quaternion
{
    result := q;
	magnitude: float = sqrt(dot(q, q));
	if(magnitude > 0)
	{
		t: float = 1.0 / magnitude;
		result.x *= t;
		result.y *= t;
		result.z *= t;
		result.w *= t;
	}
	else
	{
		result.x = 0;
		result.y = 0;
		result.z = 0;
		result.w = 1;
	}

	return result;
}