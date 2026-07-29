import { mkdir, open, rename, rm } from "node:fs/promises";

export { mkdir, open, rename };

export async function removeTemporary(file: string): Promise<void> {
  await rm(file, { force: true });
}

export async function syncDirectory(directory: string): Promise<void> {
  const handle = await open(directory, "r");
  let syncError: unknown;
  try {
    await handle.sync();
  } catch (error) {
    syncError = error;
  }

  try {
    await handle.close();
  } catch (closeError) {
    if (syncError !== undefined) {
      throw new AggregateError(
        [syncError, closeError],
        "directory sync and close failed",
      );
    }
    throw closeError;
  }
  if (syncError !== undefined) {
    throw syncError;
  }
}
