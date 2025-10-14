// CHECKITOUT: code that you add here will be prepended to all shaders

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}

// TODO-2: you may want to create a ClusterSet struct similar to LightSet
struct Cluster {
    numLights: u32,
    lightIndices: array<u32, ${numLightsPerCluster} - 1>
}

struct ClusterSet {
    numClusterX: u32,
    numClusterY: u32,
    padding1: u32,
    padding2: u32,
    clusters: array<Cluster>
}

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewProjMat: mat4x4f,
    viewMat: mat4x4f,
    projMat: mat4x4f,
    invViewMat: mat4x4f,
    invProjMat: mat4x4f,
    screenSize: vec2<u32>
}

struct Plane {
    n: vec3f,
    d: f32
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}

fn calculateLightContribViewSpace(viewMat: mat4x4f, light: Light, posView: vec3f, norView: vec3f) -> vec3f {
    let lightPos = (viewMat * vec4f(light.pos, 1.f)).xyz;
    let vecToLight = lightPos - posView;
    let distToLight = length(vecToLight);

    let lambert = max(dot(norView, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}

fn sphereIntersectsCluster(planes: array<Plane, 6>, center: vec3f, radius: f32) -> bool {
    for (var p = 0u; p < 6; p++) {
        var dist = dot(planes[p].n, center) + planes[p].d;
        if (dist > radius) {
            return false; 
        }          
    }
    return true;
}

// d should be (-linearZ) in view space
fn zIndex(d : f32) -> u32 {
    let dn = max(1e-4, ${clusterNear});
    let df = max(dn * 1.0001, ${clusterFar});
    let numClustersZ = f32(${numClustersZ});

    let t = clamp((d - dn) / (df - dn), 0.0, 0.9999999);
    return u32(floor(t * numClustersZ));
}

// given z index, return d(-linearZ) in view space
fn zBounds(index: u32) -> vec2<f32> {
    let numClustersZ = f32(${numClustersZ});
    let dn = max(1e-4, ${clusterNear});
    let df = max(dn * 1.0001, ${clusterFar});

    let t0 = f32(index)      / numClustersZ;
    let t1 = f32(index + 1u) / numClustersZ;

    let d0 = mix(dn, df, t0);
    let d1 = mix(dn, df, t1);
    return vec2<f32>(d0, d1);
}

fn posToClusterId(fragPos: vec4f, viewPos: vec3f, numClusterX: u32, numClusterY: u32) -> u32 {
    let clusterIdxX = u32(floor(fragPos.x / f32(${clusterSize})));
    let clusterIdxY = u32(floor(fragPos.y / f32(${clusterSize})));
    let clusterIdxZ = zIndex(-viewPos.z);
    let clusterIdx = clusterIdxZ + clusterIdxX * ${numClustersZ} + clusterIdxY * numClusterX * ${numClustersZ};
    return clusterIdx;
}
