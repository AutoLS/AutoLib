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

is_contained :: (a: Vector2, b: Vector2) -> bool 
{
    return b.x > a.x && b.y < a.y;
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
    cp.allocator = temp;

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

            if is_contained(projection_a, projection_b) || is_contained(projection_b, projection_a)
            {
                mins := abs(projection_a.x - projection_b.x);
                maxs := abs(projection_a.y - projection_b.y);

                o += ifx mins < maxs then mins else maxs;
            }

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

            if is_contained(projection_a, projection_b) || is_contained(projection_b, projection_a)
            {
                mins := abs(projection_a.x - projection_b.x);
                maxs := abs(projection_a.y - projection_b.y);

                o += ifx mins < maxs then mins else maxs;
            }

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

test_gjk_3d :: (shape_a: Shape, shape_b: Shape, resolution: *Resolution) -> bool
{
    // Initial direction can be arbitrary
    d := Vector3.{1, 0, 0};
    
    // Initialize simplex
    simplex: [..] Vector3;
    simplex.allocator = temp;
    
    // Get first support point
    first_point := support(shape_a, shape_b, d);
    array_add(*simplex, first_point);
    
    // Next direction is towards the origin
    d = -first_point;
    
    while true 
    {
        point := support(shape_a, shape_b, d);
        
        // If the point we found is not past the origin in the search direction
        if dot(point, d) < 0 
        {
            return false; // No collision
        }
        
        array_add(*simplex, point);
        
        if do_simplex(*simplex, *d) 
        {
            // Collision detected, generate collision data
            // Use EPA (Expanding Polytope Algorithm) to find penetration depth and normal
            normal, depth := EPA(simplex, shape_a, shape_b);
            
            resolution.normal = normal;
            resolution.depth = depth;
            resolution.mtv = normal * depth;
            
            // Generate contact points using the same method as SAT
            resolution.cp = generate_contact_point(shape_a, shape_b, resolution.normal);
            generate_contacts(resolution);
            return true;
        }
    }
    
    return false;
}

EPA :: (simplex: [..] Vector3, shape_a: Shape, shape_b: Shape) -> Vector3, float 
{
    polytope := simplex;
    polytope.allocator = temp;
    
    // Initialize faces of the polytope
    faces: [..] Face;
    faces.allocator = temp;
    
    // Create initial faces from the tetrahedron
    init_faces(*faces, polytope);
    
    closest_face: Face;
    min_dist := FLOAT32_MAX;
    
    for iterations: 0..100 
    { // Limit iterations to prevent infinite loops
        // Find face closest to origin
        closest_face, min_dist = get_closest_face(faces);
        
        // Get support point in direction of face normal
        p := support(shape_a, shape_b, closest_face.normal);
        dist := dot(p, closest_face.normal);
        
        // Check if we're done (within tolerance)
        if abs(dist - min_dist) < 0.0001 
        {
            return closest_face.normal, min_dist;
        }
        
        // Expand polytope
        expand_polytope(*polytope, *faces, p);
    }
    
    return closest_face.normal, min_dist;
}

Face :: struct {
    normal: Vector3;
    distance: float;
    indices: [3] int;
}

init_faces :: (faces: *[..] Face, polytope: [..] Vector3) #expand 
{
    // Create faces for tetrahedron
    array_add(faces, Face.{
        indices = .[0, 1, 2],
        normal = normalize(cross(polytope[1] - polytope[0], polytope[2] - polytope[0])),
    });
    
    array_add(faces, Face.{
        indices = .[0, 2, 3],
        normal = normalize(cross(polytope[2] - polytope[0], polytope[3] - polytope[0])),
    });
    
    array_add(faces, Face.{
        indices = .[0, 3, 1],
        normal = normalize(cross(polytope[3] - polytope[0], polytope[1] - polytope[0])),
    });
    
    array_add(faces, Face.{
        indices = .[1, 3, 2],
        normal = normalize(cross(polytope[3] - polytope[1], polytope[2] - polytope[1])),
    });
    
    // Calculate distances
    for * faces.* 
    {
        it.distance = dot(polytope[it.indices[0]], it.normal);
    }
}
get_closest_face :: (faces: [..] Face) -> Face, float #expand 
{
    closest_face := faces[0];
    min_dist := abs(faces[0].distance);
    
    for 1..faces.count-1 
    {
        dist := abs(faces[it].distance);
        if dist < min_dist 
        {
            min_dist = dist;
            closest_face = faces[it];
        }
    }
    
    return closest_face, min_dist;
}
expand_polytope :: (polytope: *[..] Vector3, faces: *[..] Face, point: Vector3) #expand 
{
    // Store edges to check for uniqueness
    edges: [..] Edge;
    edges.allocator = temp;
    
    // Remove faces that can see the new point
    i := 0;
    while i < faces.count 
    {
        if dot(faces.*[i].normal, point - polytope.*[faces.*[i].indices[0]]) > 0 
        {
            // Face can see point, save edges and remove face
            add_unique_edges(*edges, faces.*[i]);
            array_unordered_remove_by_index(faces, i);
        } else 
        {
            i += 1;
        }
    }
    
    // Add new point to polytope
    point_index := polytope.count;
    array_add(polytope, point);
    
    // Create new faces using saved edges and new point
    for edges 
    {
        new_face: Face;
        new_face.indices[0] = it.a;
        new_face.indices[1] = it.b;
        new_face.indices[2] = point_index;
        
        // Calculate normal and distance
        edge1 := polytope.*[new_face.indices[1]] - polytope.*[new_face.indices[0]];
        edge2 := polytope.*[new_face.indices[2]] - polytope.*[new_face.indices[0]];
        new_face.normal = normalize(cross(edge1, edge2));
        new_face.distance = dot(polytope.*[new_face.indices[0]], new_face.normal);
        
        array_add(faces, new_face);
    }
}

Edge :: struct 
{
    a, b: int;
}

add_unique_edges :: (edges: *[..] Edge, face: Face) #expand 
{
    add_if_unique :: (edges: *[..] Edge, a: int, b: int) #expand 
    {
        for edges.* 
        {
            if (it.a == a && it.b == b) || (it.a == b && it.b == a) return;
        }
        array_add(edges, Edge.{a, b});
    }
    
    add_if_unique(edges, face.indices[0], face.indices[1]);
    add_if_unique(edges, face.indices[1], face.indices[2]);
    add_if_unique(edges, face.indices[2], face.indices[0]);
}

// Support function for GJK
support :: (shape_a: Shape, shape_b: Shape, d: Vector3) -> Vector3 
{
    // Get furthest point of shape_a in direction d
    point_a := shape_a.global_vertices[get_furthest_point_index_in_direction(shape_a, d)];
    
    // Get furthest point of shape_b in opposite direction
    point_b := shape_b.global_vertices[get_furthest_point_index_in_direction(shape_b, -d)];
    
    // Return the Minkowski Difference
    return point_a - point_b;
}

// Process simplex and modify search direction
do_simplex :: (simplex: *[..] Vector3, d: *Vector3) -> bool 
{
    
    if simplex.count ==
    {
        case 2; return do_line(simplex, d);
        case 3; return do_triangle(simplex, d);
        case 4; return do_tetrahedron(simplex, d);
        case; return false; // Should never happen
    }

    return false;
}

do_line :: (simplex: *[..] Vector3, d: *Vector3) -> bool 
{
    a := simplex.*[1];
    b := simplex.*[0];
    
    ab := b - a;
    ao := -a;
    
    if same_direction(ab, ao) 
    {
        d.* = triple_product(ab, ao, ab);
    }
    else 
    {
        simplex.count = 1;
        simplex.*[0] = a;
        d.* = ao;
    }
    
    return false;
}

do_triangle :: (simplex: *[..] Vector3, d: *Vector3) -> bool 
{
    a := simplex.*[2];
    b := simplex.*[1];
    c := simplex.*[0];
    
    ab := b - a;
    ac := c - a;
    ao := -a;
    
    abc := cross(ab, ac);
    
    if same_direction(cross(abc, ac), ao) 
    {
        if same_direction(ac, ao) 
        {
            simplex.count = 2;
            simplex.*[0] = c;
            simplex.*[1] = a;
            d.* = triple_product(ac, ao, ac);
        }
        else 
        {
            simplex.count = 2;
            simplex.*[0] = b;
            simplex.*[1] = a;
            return do_line(simplex, d);
        }
    }
    else 
    {
        if same_direction(cross(ab, abc), ao) 
        {
            simplex.count = 2;
            simplex.*[0] = b;
            simplex.*[1] = a;
            return do_line(simplex, d);
        }
        else 
        {
            if same_direction(abc, ao) 
            {
                d.* = abc;
            }
            else 
            {
                simplex.*[0] = b;
                simplex.*[1] = c;
                simplex.*[2] = a;
                d.* = -abc;
            }
        }
    }
    
    return false;
}

do_tetrahedron :: (simplex: *[..] Vector3, dir: *Vector3) -> bool 
{
    a := simplex.*[3];
    b := simplex.*[2];
    c := simplex.*[1];
    d := simplex.*[0];
    
    ab := b - a;
    ac := c - a;
    ad := d - a;
    ao := -a;
    
    abc := cross(ab, ac);
    acd := cross(ac, ad);
    adb := cross(ad, ab);
    
    if same_direction(abc, ao) 
    {
        simplex.count = 3;
        simplex.*[0] = c;
        simplex.*[1] = b;
        simplex.*[2] = a;
        return do_triangle(simplex, dir);
    }
    
    if same_direction(acd, ao) 
    {
        simplex.count = 3;
        simplex.*[0] = d;
        simplex.*[1] = c;
        simplex.*[2] = a;
        return do_triangle(simplex, dir);
    }
    
    if same_direction(adb, ao) 
    {
        simplex.count = 3;
        simplex.*[0] = b;
        simplex.*[1] = d;
        simplex.*[2] = a;
        return do_triangle(simplex, dir);
    }
    
    return true;
}

same_direction :: (v1: Vector3, v2: Vector3) -> bool 
{
    return dot(v1, v2) > 0;
}

triple_product :: (a: Vector3, b: Vector3, c: Vector3) -> Vector3 
{
    return cross(cross(a, b), c);
}
