// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> camUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;

@group(1) @binding(0) var albedoTex: texture_2d<f32>;
@group(1) @binding(1) var normalTex: texture_2d<f32>;
@group(1) @binding(2) var depthTex: texture_depth_2d;
@group(1) @binding(3) var nearestSampler: sampler;

@group(2) @binding(0) var<storage, read> clusterSet: ClusterSet;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) uv: vec2f,
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let uv = vec2f(in.uv.x, 1.0 - in.uv.y);
    let diffuseColor = textureSample(albedoTex, nearestSampler, uv).xyz;
    let normal = textureSample(normalTex, nearestSampler, uv).xyz;
    let depth = textureLoad(depthTex, vec2<i32>(in.fragPos.xy), 0);

    var viewPos = vec4f(in.uv * 2.0 - 1.0, depth, 1.0);
    viewPos = camUniforms.invProjMat * viewPos;
    viewPos = viewPos / viewPos.w;

    var clusterId = posToClusterId(in.fragPos, viewPos.xyz, clusterSet.numClusterX, clusterSet.numClusterY);
    let numLights = clusterSet.clusters[clusterId].numLights;

    var totalLightContrib = vec3f(0, 0, 0);
    for (var lightIdx = 0u; lightIdx < numLights; lightIdx++) {
        let light = lightSet.lights[clusterSet.clusters[clusterId].lightIndices[lightIdx]];
        let normalView = (camUniforms.viewMat * vec4f(normalize(normal), 0.0)).xyz;
        totalLightContrib += calculateLightContribViewSpace(camUniforms.viewMat, light, viewPos.xyz, normalView);
    }

    // var finalColor = vec3f(1, 1, 1) * f32(clusterId) / f32(clusterSet.numClusterX * clusterSet.numClusterY * ${numClustersZ});
    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}