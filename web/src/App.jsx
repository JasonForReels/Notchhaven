const REPO = 'https://github.com/JasonForReels/Notchhaven'

const features = [
  ['Live Activities', 'Now Playing with artwork, visualizer and lyrics; downloads, AirDrop, timers, screen recording, Focus, Personal Hotspot.'],
  ['Temporary alerts', 'Charging, low and full battery, Bluetooth, Wi-Fi, VPN and volume/brightness HUDs.'],
  ['Lock screen', 'Media and live activity surfaces that carry through lock and unlock transitions.'],
  ['Gestures', 'Drag, swipe and scroll to dismiss or restore, with adaptive corners and swipe-aware blur.'],
  ['Fluid physics', 'Jelly-like morphing, squash and stretch, and synchronized content interpolation.'],
  ['Works without a notch', 'On non-notched Macs and external displays it becomes a floating Dynamic Island capsule.'],
  ['Deep customization', 'Notch size, stroke, background, animation presets, display selection and fullscreen handling.'],
  ['38+ languages', 'Fully localized interface, activities and settings, switchable instantly.'],
]

const gallery = [
  ['Timer', 'Timer'], ['Tray', 'Tray'], ['Downloads', 'Downloads'], ['Charging', 'Charging'],
  ['LowBattery', 'Low battery'], ['FullBattery', 'Full battery'], ['Bluetooth', 'Bluetooth'],
  ['VpnConnection', 'VPN'], ['VolumeHud', 'Volume HUD'], ['Hotspot', 'Personal Hotspot'],
  ['NoInternet', 'No internet'], ['FocusMode', 'Focus mode'],
]

const hookSnippet = `{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "/path/to/Notchhaven/scripts/claude-notch-hook.sh" }] }],
    "PreToolUse":       [ ... same hook ... ],
    "Notification":     [ ... same hook ... ],
    "Stop":             [ ... same hook ... ],
    "SessionEnd":       [ ... same hook ... ]
  }
}`

const Shot = ({ name, alt, lazy }) => (
  <div className="shot"><img src={`/img/${name}.jpg`} alt={alt} loading={lazy ? 'lazy' : undefined} /></div>
)

export default function App() {
  return (
    <div className="wrap">
      <nav>
        <a className="brand" href="#"><img src="/img/icon.png" alt="" />Notchhaven</a>
        <div className="links">
          <a href="#features">Features</a><a href="#gallery">Gallery</a>
          <a href="#claude">Claude Code</a><a href="#install">Install</a>
        </div>
      </nav>

      <header className="hero">
        <div className="pill" aria-hidden="true"><i />Now playing</div>
        <h1>The notch,<br />finally useful.</h1>
        <p className="tag">Notchhaven turns the MacBook notch into a live native surface for media, downloads, AirDrop, timers, HUDs and even Claude Code.</p>
        <div className="cta">
          <a className="btn" href={`${REPO}/releases`}>Download for macOS</a>
          <a className="btn alt" href={REPO}>View on GitHub</a>
        </div>
        <div className="heroShot"><Shot name="Player" alt="Now Playing in the notch with album art, progress and controls" /></div>
      </header>

      <section id="features">
        <h2>Built like part of macOS</h2>
        <p className="sub">SwiftUI and AppKit, with its own engine that mirrors the spring physics and morphing of the iPhone Dynamic Island.</p>
        <div className="grid">
          {features.map(([t, d]) => (
            <div className="card" key={t}><h3>{t}</h3><p>{d}</p></div>
          ))}
        </div>
      </section>

      <section className="split">
        <div>
          <h2>Lock screen, covered</h2>
          <p className="sub" style={{ margin: 0 }}>Media and activities stay visible on the lock screen without stealing focus.</p>
        </div>
        <Shot name="LockScreen" alt="Notchhaven on the macOS lock screen" lazy />
      </section>

      <section id="gallery">
        <h2>Gallery</h2>
        <p className="sub">A small selection of the states and alerts Notchhaven supports.</p>
        <div className="gallery">
          {gallery.map(([file, label]) => (
            <figure key={file}><Shot name={file} alt={label} lazy /><figcaption>{label}</figcaption></figure>
          ))}
        </div>
      </section>

      <section id="claude">
        <h2>Claude Code in the notch</h2>
        <p className="sub">See when Claude Code is thinking, running a tool, waiting on you, or done, with a snippet of its last reply. It is off by default and listens on loopback only (<code>127.0.0.1:26540</code>).</p>
        <pre><code>{hookSnippet}</code></pre>
        <p className="sub">Turn on <b>Show Claude Activity</b> in the menu bar menu, then add the hooks above to <code>~/.claude/settings.json</code>.</p>
      </section>

      <section id="install">
        <h2>Get started</h2>
        <ol className="steps">
          <li><b>Download</b> the latest DMG from <a href={`${REPO}/releases`}>Releases</a>.</li>
          <li><b>Drag</b> the app into Applications and launch it.</li>
          <li><b>Grant</b> permissions for the features you want (Accessibility, Bluetooth, Screen Recording, Media).</li>
          <li>If macOS blocks the first launch, allow it in System Settings → Privacy &amp; Security.</li>
        </ol>
        <p className="sub">Requires macOS 14.6 or later. Open source under GPL-3.0.</p>
      </section>

      <footer>
        Notchhaven is a fork of <a href="https://github.com/jackson-storm/DynamicNotch">DynamicNotch</a> by jackson-storm, licensed under GPL-3.0.<br />
        <a href={REPO}>GitHub</a> · <a href={`${REPO}/releases`}>Releases</a>
      </footer>
    </div>
  )
}
