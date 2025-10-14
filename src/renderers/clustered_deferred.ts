import * as renderer from "../renderer";
import * as shaders from "../shaders/shaders";
import { Stage } from "../stage/stage";

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    clusteredLightsBindGroupLayout: GPUBindGroupLayout;
    clusteredLightsBindGroup: GPUBindGroup;

    gBufferBindGroupLayout: GPUBindGroupLayout;
    gBufferBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    albedoTexture: GPUTexture;
    albedoTextureView: GPUTextureView;

    normalTexture: GPUTexture;
    normalTextureView: GPUTextureView;

    nearestSampler: GPUSampler;

    gBufferPipeline: GPURenderPipeline;
    shadingPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass
        this.sceneUniformsBindGroupLayout =
            renderer.device.createBindGroupLayout({
                label: "scene uniforms bind group layout",
                entries: [
                    // TODO-1.2: add an entry for camera uniforms at binding 0, visible to only the vertex shader, and of type "uniform"
                    {
                        // Uniforms
                        binding: 0,
                        visibility:
                            GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                        buffer: { type: "uniform" },
                    },
                    {
                        // lightSet
                        binding: 1,
                        visibility: GPUShaderStage.FRAGMENT,
                        buffer: { type: "read-only-storage" },
                    },
                ],
            });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                // TODO-1.2: add an entry for camera uniforms at binding 0
                // you can access the camera using `this.camera`
                // if you run into TypeScript errors, you're probably trying to upload the host buffer instead
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer },
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer },
                },
            ],
        });

        this.clusteredLightsBindGroupLayout =
            renderer.device.createBindGroupLayout({
                label: "clustered lights bind group layout",
                entries: [
                    {
                        // light array
                        binding: 0,
                        visibility: GPUShaderStage.FRAGMENT,
                        buffer: { type: "read-only-storage" },
                    },
                ],
            });

        this.clusteredLightsBindGroup = renderer.device.createBindGroup({
            label: "clustered lights bind group",
            layout: this.clusteredLightsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.lights.clusteredLightsStorageBuffer,
                    },
                },
            ],
        });

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage:
                GPUTextureUsage.RENDER_ATTACHMENT |
                GPUTextureUsage.TEXTURE_BINDING,
        });
        this.depthTextureView = this.depthTexture.createView();

        this.albedoTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba8unorm",
            usage:
                GPUTextureUsage.RENDER_ATTACHMENT |
                GPUTextureUsage.TEXTURE_BINDING,
        });
        this.albedoTextureView = this.albedoTexture.createView();

        this.normalTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage:
                GPUTextureUsage.RENDER_ATTACHMENT |
                GPUTextureUsage.TEXTURE_BINDING,
        });
        this.normalTextureView = this.normalTexture.createView();

        this.nearestSampler = renderer.device.createSampler({
            magFilter: "nearest",
            minFilter: "nearest",
            mipmapFilter: "nearest",
            addressModeU: "clamp-to-edge",
            addressModeV: "clamp-to-edge",
            addressModeW: "clamp-to-edge",
        });

        this.gBufferBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "gbuffer bind group layout",
            entries: [
                {
                    // albedo
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float" },
                },
                {
                    // normal
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float" },
                },
                {
                    // depth
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "depth" },
                },
                {
                    // sampler
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {},
                },
            ],
        });

        this.gBufferBindGroup = renderer.device.createBindGroup({
            label: "gbuffer bind group",
            layout: this.gBufferBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.albedoTextureView,
                },
                {
                    binding: 1,
                    resource: this.normalTextureView,
                },
                {
                    binding: 2,
                    resource: this.depthTextureView,
                },
                {
                    binding: 3,
                    resource: this.nearestSampler,
                },
            ],
        });

        this.gBufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "clustered_deferred gbuffer pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout,
                ],
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus",
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    // the same as naive
                    label: "naive vert shader",
                    code: shaders.naiveVertSrc,
                }),
                buffers: [renderer.vertexBufferLayout],
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered_deferred frag shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    {
                        format: "rgba8unorm",
                    },
                    {
                        format: "rgba16float",
                    },
                ],
            },
        });

        this.shadingPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "clustered_deferred shading pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.gBufferBindGroupLayout,
                    this.clusteredLightsBindGroupLayout,
                ],
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered_deferred fullscreen vert shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc,
                }),
                buffers: [], // no vertex buffers
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered_deferred fullscreen frag shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    },
                ],
            },
        });
    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context
            .getCurrentTexture()
            .createView();

        // - run the clustering compute shader
        this.lights.doLightClustering(encoder);

        // - run the G-buffer pass, outputting position, albedo, and normals
        const gBufferRenderPass = encoder.beginRenderPass({
            label: "clustered_deferred gbuffer render pass",
            colorAttachments: [
                {
                    view: this.albedoTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store",
                },
                {
                    view: this.normalTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store",
                },
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store",
            },
        });
        gBufferRenderPass.setPipeline(this.gBufferPipeline);

        // scene uniforms
        gBufferRenderPass.setBindGroup(
            shaders.constants.bindGroup_scene,
            this.sceneUniformsBindGroup
        );

        this.scene.iterate(
            (node) => {
                gBufferRenderPass.setBindGroup(
                    shaders.constants.bindGroup_model,
                    node.modelBindGroup
                );
            },
            (material) => {
                gBufferRenderPass.setBindGroup(
                    shaders.constants.bindGroup_material,
                    material.materialBindGroup
                );
            },
            (primitive) => {
                gBufferRenderPass.setVertexBuffer(0, primitive.vertexBuffer);
                gBufferRenderPass.setIndexBuffer(
                    primitive.indexBuffer,
                    "uint32"
                );
                gBufferRenderPass.drawIndexed(primitive.numIndices);
            }
        );

        gBufferRenderPass.end();

        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations
        const shadingRenderPass = encoder.beginRenderPass({
            label: "clustered_deferred shading render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store",
                },
            ],
        });
        shadingRenderPass.setPipeline(this.shadingPipeline);

        // scene uniforms
        shadingRenderPass.setBindGroup(
            shaders.constants.bindGroup_scene,
            this.sceneUniformsBindGroup
        );

        // gbuffer
        shadingRenderPass.setBindGroup(1, this.gBufferBindGroup);

        // clustered lights
        shadingRenderPass.setBindGroup(2, this.clusteredLightsBindGroup);

        // draw
        shadingRenderPass.draw(3); // fullscreen triangle

        shadingRenderPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}
