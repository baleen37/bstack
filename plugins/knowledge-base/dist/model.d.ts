export { verifyModelFile } from "./model-verify.js";
export declare const MODEL_SPEC: Readonly<{
    readonly url: "https://huggingface.co/n24q02m/Qwen3-Embedding-0.6B-GGUF/resolve/4aea43eaa9633282b1eee7be8cf7ac59a0011709/qwen3-embedding-0.6b-q4-k-m.gguf";
    readonly size: 396474496;
    readonly sha256: "690ce73e3716962cbdbfb0dcb9ea6ad633430101ba3247c6e6d36cbdd06f3871";
}>;
export declare function ensureModel(destination: string, fetchImpl?: typeof fetch): Promise<string>;
