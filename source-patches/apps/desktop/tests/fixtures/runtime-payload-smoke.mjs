/**
 * Encode and decode a pixel through sharp's packaged backend.
 *
 * On Linux, sharp must run its WebAssembly build. Electron's Linux executable links the system
 * GLib, and sharp's native Linux backend carries its own static GLib; the native addon's
 * g_object_unref binds to Electron's copy for objects its own copy created, and image work
 * crashes the Host with SIGSEGV. `installSharpWasmResolution` refuses the native packages so
 * sharp falls back to @img/sharp-wasm32. The packaged tree must have @img/sharp-wasm32 and
 * must not have any @img/sharp-linux-* package. The pixel round-trip proves whichever backend
 * loaded actually works.
 */
async function checkSharp() {
  const sharp = requireRuntime('sharp')
  // Check package presence, not sharp.versions: sharp.versions reports native library versions
  // (sharp, vips, cwebp, ...), not the @img binding package names, so a check for 'sharp-wasm32'
  // in sharp.versions never succeeds on any platform. sharp/package.json is not in sharp's
  // exports map, so resolve the main entry and walk up to node_modules instead.
  const sharpEntry = requireRuntime.resolve('sharp')
  const nodeModules = join(dirname(sharpEntry), '..', '..')
  const imgDir = join(nodeModules, '@img')
  const entries = existsSync(imgDir) ? readdirSync(imgDir) : []
  const nativeLinux = entries.filter(name => /^sharp-(?:libvips-)?linux/u.test(name))
  const hasWasm = entries.includes('sharp-wasm32')
  if (process.platform === 'linux') {
    assert.deepEqual(nativeLinux, [],
      `packaged runtime: native Linux sharp bindings present (${nativeLinux.join(', ')}); only @img/sharp-wasm32 may be packaged on Linux`)
    assert.ok(hasWasm,
      `packaged runtime: @img/sharp-wasm32 is missing from node_modules/@img (${entries.join(', ') || 'empty'}); Linux sharp must fall back to WASM`)
  }
  const pixel = Buffer.from([17, 103, 231])
  const png = await sharp(pixel, { raw: { width: 1, height: 1, channels: 3 } }).png().toBuffer()
  const decoded = await sharp(png).raw().toBuffer({ resolveWithObject: true })
  assert.equal(decoded.info.width, 1)
  assert.equal(decoded.info.height, 1)
  assert.equal(decoded.info.channels, 3)
  assert.deepEqual(decoded.data, pixel)
}
