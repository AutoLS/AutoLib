Clipping_Edge :: struct
{
    edge: Vector3;
    v1: Vector3;
    v2: Vector3;
    furthest: Vector3;
}

Contact :: struct
{
    b: float;

    normal: Vector3;
    depth: float;

    rel_pos_a: Vector3;
    rel_pos_b: Vector3;

    sum_impulse_contact: float;
    sum_impulse_friction: Vector3;
}

Resolution :: struct
{
    body_a: *Rigid_Body;
    body_b: *Rigid_Body;
    normal: Vector3;
    depth: float;
    mtv: Vector3;

    cp: [..] Vector3;
    contacts: [..] Contact;
}

generate_test_axes :: (using shape: Shape) -> [..] Vector3
{
    axes: [..] Vector3;
    axes.allocator = temp;

    for global_vertices 
    {
        p1 := it;
        p2 := global_vertices[(it_index+1) % global_vertices.count];

        edge := p2 - p1;

        n := to_vector3(cross(edge.xy, -1));
        array_add(*axes, normalize(n));
    }

    return axes;
}

project_to_axis :: (axis: Vector3, shape: Shape) -> Vector2
{
    min: float = dot(axis, shape.global_vertices[0]);
    result := Vector2.{min, min};

    for 1 .. shape.vertices_count-1
    {
        projection := dot(axis, shape.global_vertices[it]);
        if projection < result.x
        {
            result.x = projection;
        }
        else if projection > result.y  
        {
            result.y = projection;
        }
    }

    return result;
}

is_projection_overlapped :: (a: Vector2, b: Vector2) -> bool
{
    return !(b.y < a.x || a.y < b.x);
}

get_overlap_from_projection :: (a: Vector2, b: Vector2) -> float
{
    return min(a.y, b.y) - max(a.x, b.x);
}

//NOTE: Winding order is counter clockwise
find_best_edge :: (shape: Shape, n: Vector3) -> Clipping_Edge
{
    result: Clipping_Edge;
    index := get_furthest_point_index_in_direction(shape, n);
    index_prev := ifx index - 1 < 0 then shape.vertices_count-1 else index - 1;
    index_next := ifx index + 1 == shape.vertices_count then 0 else index + 1;

    result.furthest = shape.global_vertices[index];

    v := shape.global_vertices[index];
    v_next := shape.global_vertices[index_next];
    v_prev := shape.global_vertices[index_prev];

    l := normalize(v - v_next);
    r := normalize(v - v_prev);

    if dot(r, n) <= dot(l, n)
    {
        result.v1 = v_prev;
        result.v2 = v;
        result.edge = result.v2 - result.v1;
    }
    else
    {
        result.v1 = v;
        result.v2 = v_next;
        result.edge = result.v2 - result.v1;
    }

    return result;
}

clip :: (v1: Vector3, v2: Vector3, n: Vector3, o: float) -> [..] Vector3
{
    cp: [..] Vector3;

    d1 := dot(n, v1) - o;
    d2 := dot(n, v2) - o;

    if d1 >= 0 array_add(*cp, v1);
    if d2 >= 0 array_add(*cp, v2);

    if d1 * d2 < 0
    {
        e := v2 - v1;
        u: float = d1 / (d1 - d2);
        e = e * u;
        e += v1;

        array_add(*cp, e);
    }

    return cp;
}

generate_contact_point :: (shape_a: Shape, shape_b: Shape, normal: Vector3) -> [..] Vector3
{
    cp: [..] Vector3;
    cp.allocator = temp;
    e1 := find_best_edge(shape_a, normal);
    e2 := find_best_edge(shape_b, -normal);
    
    ref, inc: Clipping_Edge;
    flip := false;
    if(abs(dot(e1.edge, normal)) <= abs(dot(e2.edge, normal)))
    {
        ref = e1;
        inc = e2;
    }
    else
    {
        ref = e2;
        inc = e1;
        flip = true;
    }

    refv := normalize(ref.edge);

    o1 := dot(refv, ref.v1);
    cp = clip(inc.v1, inc.v2, refv, o1);
    if(cp.count < 2) 
    {
        array_reset(*cp);
        return cp;
    }

    o2 := dot(refv, ref.v2);
    cp = clip(cp[0], cp[1], -refv, -o2);
    if(cp.count < 2)
    {
        array_reset(*cp);
        return cp;
    }

    //NOTE: if we flipped we have to use the left hand orthogonal vector otherwise use right hand
    ref_n := ifx flip then to_vector3(reverse_perp(refv.xy)) else to_vector3(perp(refv.xy));

    if(flip) ref_n = -ref_n;

    max := dot(ref_n, ref.furthest);

    d0 := dot(ref_n, cp[0]);
    d1 := dot(ref_n, cp[1]);

    if(d1 - max < 0)
    {
        array_unordered_remove_by_index(*cp, 1);
    }
    if(d0 - max < 0)
    {
        array_unordered_remove_by_index(*cp, 0);
    }

    return cp;
}

generate_contacts :: (using resolution: *Resolution)
{
    for cp 
    {
        c: Contact;
        r1 := it - body_a.position;
        r2 := it - body_b.position;

        c.rel_pos_a = r1;
        c.rel_pos_b = r2;
        c.normal = normal;
        c.depth = depth;

        array_add(*contacts, c);
    }
}

test_SAT :: (shape_a: Shape, shape_b: Shape, resolution: *Resolution) -> bool
{
    overlap: float = FLOAT32_MAX;
    smallest: Vector3;

    axes_a := generate_test_axes(shape_a);
    axes_b := generate_test_axes(shape_b);

    for axes_a 
    {
        projection_a := project_to_axis(it, shape_a);
        projection_b := project_to_axis(it, shape_b);

        if !is_projection_overlapped(projection_a, projection_b)
        {
            return false;
        }
        else
        {
            o: float = get_overlap_from_projection(projection_a, projection_b);
            if o < overlap
            {
                overlap = o;
                smallest = ifx projection_a.y > projection_b.y then -it else it; 
            }
        }
    }

    for axes_b 
    {
        projection_a := project_to_axis(it, shape_a);
        projection_b := project_to_axis(it, shape_b);

        if !is_projection_overlapped(projection_a, projection_b)
        {
            return false;
        }
        else
        {
            o: float = get_overlap_from_projection(projection_a, projection_b);
            if o < overlap
            {
                overlap = o;
                smallest = ifx projection_a.y > projection_b.y then -it else it; 
            }
        }
    }

    resolution.normal = smallest;
    resolution.depth = xx overlap;
    resolution.mtv = smallest * overlap;
    resolution.cp = generate_contact_point(shape_a, shape_b, resolution.normal);
    generate_contacts(resolution);

    return true;
}