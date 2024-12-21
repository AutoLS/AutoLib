Polygon :: enum u32
{
    Rect;
    Triangle;
    Right_Triangle;
}

Shape :: struct
{
    local_vertices: [..] Vector3;
    global_vertices: [..] Vector3;
    vertices_count: s32;

    center: Vector3;
    scale: Vector3;

    radius: float;

    model: Matrix4;

    type: Polygon;
}

make_rect :: (position: Vector3 = .{}, scale: Vector3 = .{}) -> Shape
{
    rect: Shape;
    rect.type = .Rect;
    rect.center = position;
    rect.scale = scale;
    update_shape_model(*rect);
    rect.vertices_count = 4;

    array_add(*rect.local_vertices, Vector3.{-0.5, 0.5, 0});
    array_add(*rect.local_vertices, Vector3.{-0.5, -0.5, 0});
    array_add(*rect.local_vertices, Vector3.{0.5, -0.5, 0});
    array_add(*rect.local_vertices, Vector3.{0.5, 0.5, 0});
    for 0 .. rect.vertices_count-1 
    {
        array_add(*rect.global_vertices, .{});
    }
    update_shape_vertices(*rect);

    return rect;
}

make_right_triangle :: (position: Vector3 = .{}, scale: Vector3 = .{}) -> Shape
{
    tri: Shape;
    tri.type = .Right_Triangle;
    tri.center = position;
    tri.scale = scale;
    update_shape_model(*tri);
    tri.vertices_count = 3;
    array_add(*tri.local_vertices, Vector3.{-0.5, 0.5, 0});
    array_add(*tri.local_vertices, Vector3.{-0.5, -0.5, 0});
    array_add(*tri.local_vertices, Vector3.{0.5, -0.5, 0});

    for 0 .. tri.vertices_count-1 
    {
        array_add(*tri.global_vertices, .{});
    }
    update_shape_vertices(*tri);

    return tri;
}

get_furthest_vertex :: (using shape: Shape) -> Vector3
{
    max: float = -FLOAT32_MAX;
    index := 0;

    for global_vertices
    {
        d := length(it - center);
        if d > max 
        {
            max = d;
            index = it_index;
        }
    }

    return global_vertices[index];
}

get_furthest_point_index_in_direction :: (using shape: Shape, dir: Vector3) -> int
{
    max: float = -FLOAT32_MAX;
    index: int = 0;

    for global_vertices
    {
        projection := dot(it, dir);
        if projection > max
        {
            max = projection;
            index = it_index;
        }
    }

    return index;
}

get_shape_radius :: (using shape: Shape) -> float
{
    return length(get_furthest_vertex(shape) - center);
}

update_shape_model :: (using shape: *Shape)
{
    model = make_model_matrix(center, scale);
}

update_shape_model :: (using shape: *Shape, new_position: Vector3, new_scale: Vector3, axis: Vector3 = .{}, angle: float = 0)
{
    center = new_position;
    scale = new_scale;
    model = make_model_matrix(new_position, new_scale, axis, angle);
}

update_shape_model :: (using shape: *Shape, new_position: Vector3, new_scale: Vector3, q: Quaternion)
{
    center = new_position;
    scale = new_scale;
    model = make_model_matrix(new_position, new_scale, q);
}

update_shape_vertices :: (using shape: *Shape)
{
    for local_vertices
    {
        updated_vertex := Vector4.{it.x, it.y, it.z, 1};
        updated_vertex = model * updated_vertex; 
        global_vertices[it_index] = updated_vertex.xyz;
    }

    radius = get_shape_radius(shape);
}

update_shape :: (using shape: *Shape)
{
    update_shape_model(shape);
    update_shape_vertices(shape);
}

update_shape :: (using shape: *Shape, new_position: Vector3, new_scale: Vector3, q: Quaternion)
{
    update_shape_model(shape, new_position, new_scale, q);
    update_shape_vertices(shape);
}