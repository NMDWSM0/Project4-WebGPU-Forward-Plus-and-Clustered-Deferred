// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct FragmentOutput {
    @location(0) outPacked : vec4u
};

@fragment
fn main(in: FragmentInput) -> FragmentOutput
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var o: FragmentOutput;
    let packedAlbedo = pack4x8unorm(diffuseColor);
    let packedNormal = pack2x16snorm(encodeOct(in.nor));
    let packedDepth = bitcast<u32>(in.fragPos.z);
    o.outPacked = vec4u(packedAlbedo, packedNormal, packedDepth, 0u);

    return o;
}