// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

@group(0) @binding(0) var<uniform> camUniforms: CameraUniforms;

@group(1) @binding(0) var<storage, read> lightSet: LightSet;
@group(1) @binding(1) var<storage, read_write> clusterSet : ClusterSet;

fn rayFromNdcXY(ndcXY: vec2<f32>) -> vec3<f32> {
    let p4 = camUniforms.invProjMat * vec4<f32>(ndcXY, 1.0, 1.0);
    let pv = p4.xyz / p4.w;
    return normalize(pv);
}

@compute
@workgroup_size(${clusterLightsWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let id = globalIdx.x;
    if (id >= clusterSet.numClusterX * clusterSet.numClusterY * ${numClustersZ}) {
        return;
    }
    let clusterIdY = id / (clusterSet.numClusterX * ${numClustersZ});
    let idXZ = id - clusterIdY * (clusterSet.numClusterX * ${numClustersZ});
    let clusterIdX = idXZ / ${numClustersZ};
    let clusterIdZ = idXZ - clusterIdX * ${numClustersZ};

    let x0 = (f32(clusterIdX)      / f32(clusterSet.numClusterX)) * 2.0 - 1.0;
    let x1 = (f32(clusterIdX + 1u) / f32(clusterSet.numClusterX)) * 2.0 - 1.0;
    let y1 = 1.0 - (f32(clusterIdY)      / f32(clusterSet.numClusterY)) * 2.0;
    let y0 = 1.0 - (f32(clusterIdY + 1u) / f32(clusterSet.numClusterY)) * 2.0;

    let r00 = rayFromNdcXY(vec2<f32>(x0, y0)); // left-bottom
    let r10 = rayFromNdcXY(vec2<f32>(x1, y0)); // right-bottom
    let r01 = rayFromNdcXY(vec2<f32>(x0, y1)); // left-top
    let r11 = rayFromNdcXY(vec2<f32>(x1, y1)); // right-top

    var nL = normalize(cross(r01, r00)); // left (x = x0)
    var nR = normalize(cross(r10, r11)); // right (x = x1)
    var nB = normalize(cross(r00, r10)); // bottom (y = y0)
    var nT = normalize(cross(r11, r01)); // up (y = y1)

    let dz = zBounds(clusterIdZ);
    let dNearSlice = dz.x;
    let dFarSlice = dz.y;

    let nNear = vec3<f32>(0.0, 0.0, 1.0);
    let dNear = dNearSlice;

    let nFar = vec3<f32>(0.0, 0.0, -1.0);
    let dFar = -dFarSlice;

    let planes = array<Plane, 6>(
    Plane(nL, 0.0), 
    Plane(nR, 0.0),
    Plane(nB, 0.0), 
    Plane(nT, 0.0),
    Plane(nNear, dNear), 
    Plane(nFar, dFar));

    var numLights : u32 = 0;
    for (var lightIdx : u32 = 0; lightIdx < lightSet.numLights; lightIdx++) {
        if (numLights >= ${numLightsPerCluster} - 1){
            break;
        }
        // check light
        let light = lightSet.lights[lightIdx];
        let lightPos = (camUniforms.viewMat * vec4f(light.pos, 1.f)).xyz;
        if (sphereIntersectsCluster(planes, lightPos, ${lightRadius})) 
        {
            clusterSet.clusters[id].lightIndices[numLights] = lightIdx;
            numLights++;
        }
    }
    clusterSet.clusters[id].numLights = numLights;
}