export declare class ModelValidationError extends Error {
}
export declare function verifyModelFile(file: string, expected: {
    size: number;
    sha256: string;
}): Promise<void>;
