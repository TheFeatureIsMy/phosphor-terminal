/**
 * Crypto utilities (for hashing, not encryption)
 */

export async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message)
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

export function generateId(): string {
  return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)
}

export function generateUUID(): string {
  return crypto.randomUUID()
}

export function base64Encode(str: string): string {
  return btoa(str)
}

export function base64Decode(str: string): string {
  return atob(str)
}
