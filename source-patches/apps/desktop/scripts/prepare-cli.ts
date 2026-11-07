/** Package terminal launch scripts that reuse the installed Electron runtime. */

import { chmodSync, copyFileSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'

/**
 * Copy the platform launcher into the application's public command directory.
 * @param destination - Physical runtime/cli directory prepared for the application.
 * @param platform - Target Desktop operating system.
 */
export function prepareDesktopCli(destination: string, platform: 'darwin' | 'win32' | 'linux'): void {
  // win32 uses the .cmd batch wrapper; macOS and Linux both use the POSIX shell
  // script. Linux does not need the chmod step that macOS gets below: the CLI
  // launcher is already executable in the packaged tree (electron-builder and
  // the runtime materialize step preserve the mode), and the `dsh` shell script
  // is invoked by its full path from the launcher, not by a findable name.
  const name = platform === 'win32' ? 'dsh.cmd' : 'dsh'
  const command = join(destination, 'bin', name)
  mkdirSync(join(destination, 'bin'), { recursive: true })
  copyFileSync(join(import.meta.dirname, '..', 'cli', name), command)
  if (platform === 'darwin') chmodSync(command, 0o755)
}
