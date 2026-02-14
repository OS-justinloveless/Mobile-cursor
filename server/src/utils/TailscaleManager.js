import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

/**
 * TailscaleManager - Detects and manages Tailscale network integration
 * 
 * This is an optional feature. When Tailscale is installed and connected,
 * the server will advertise its Tailscale IP and MagicDNS hostname so
 * iOS clients on the same tailnet can discover and connect to it.
 */
class TailscaleManager {
  constructor() {
    this._status = null;
    this._lastCheck = 0;
    this._cacheDurationMs = 30000; // Cache for 30 seconds
    this._available = null; // null = unchecked, true/false after check
  }

  /**
   * Check if the tailscale CLI is available
   */
  async isAvailable() {
    if (this._available !== null) {
      return this._available;
    }

    try {
      await execFileAsync('which', ['tailscale']);
      this._available = true;
    } catch {
      // Try common install locations
      try {
        await execFileAsync('/usr/local/bin/tailscale', ['version']);
        this._available = true;
      } catch {
        try {
          await execFileAsync('/Applications/Tailscale.app/Contents/MacOS/Tailscale', ['version']);
          this._available = true;
        } catch {
          this._available = false;
        }
      }
    }

    return this._available;
  }

  /**
   * Get the tailscale binary path
   */
  async _getTailscaleBin() {
    const paths = [
      'tailscale',
      '/usr/local/bin/tailscale',
      '/Applications/Tailscale.app/Contents/MacOS/Tailscale',
    ];

    for (const p of paths) {
      try {
        await execFileAsync(p, ['version']);
        return p;
      } catch {
        // try next
      }
    }
    return null;
  }

  /**
   * Get Tailscale status (cached)
   * Returns null if Tailscale is not available or not connected
   */
  async getStatus() {
    const now = Date.now();
    if (this._status && (now - this._lastCheck) < this._cacheDurationMs) {
      return this._status;
    }

    if (!(await this.isAvailable())) {
      return null;
    }

    try {
      const bin = await this._getTailscaleBin();
      if (!bin) return null;

      const { stdout } = await execFileAsync(bin, ['status', '--json'], {
        timeout: 10000,
        maxBuffer: 1024 * 1024,
      });

      const statusJson = JSON.parse(stdout);
      
      // Extract relevant info
      const selfNode = statusJson.Self;
      if (!selfNode) return null;

      // Get the Tailscale IP (first IP, usually the IPv4 100.x.y.z)
      const tailscaleIPs = selfNode.TailscaleIPs || [];
      const ipv4 = tailscaleIPs.find(ip => ip.startsWith('100.'));
      const ipv6 = tailscaleIPs.find(ip => ip.includes(':'));

      // Get MagicDNS hostname
      const dnsName = selfNode.DNSName || '';
      // DNSName looks like "hostname.tailnet-name.ts.net." - strip trailing dot
      const magicDNSHostname = dnsName.endsWith('.') ? dnsName.slice(0, -1) : dnsName;

      // Get tailnet name from the DNS name
      let tailnetName = '';
      if (magicDNSHostname) {
        const parts = magicDNSHostname.split('.');
        if (parts.length >= 3) {
          // hostname.tailnet-name.ts.net -> tailnet-name.ts.net
          tailnetName = parts.slice(1).join('.');
        }
      }

      // Get peer list
      const peers = [];
      if (statusJson.Peer) {
        for (const [, peer] of Object.entries(statusJson.Peer)) {
          if (!peer.Active && !peer.Online) continue; // Skip offline peers

          const peerIPs = peer.TailscaleIPs || [];
          const peerIpv4 = peerIPs.find(ip => ip.startsWith('100.'));
          const peerDNSName = peer.DNSName || '';
          const peerHostname = peerDNSName.endsWith('.')
            ? peerDNSName.slice(0, -1)
            : peerDNSName;

          peers.push({
            hostname: peer.HostName || '',
            dnsName: peerHostname,
            ip: peerIpv4 || peerIPs[0] || '',
            os: peer.OS || '',
            online: peer.Online || false,
            active: peer.Active || false,
          });
        }
      }

      this._status = {
        connected: true,
        ip: ipv4 || '',
        ipv6: ipv6 || '',
        hostname: selfNode.HostName || '',
        magicDNSHostname,
        tailnetName,
        peers,
        backendState: statusJson.BackendState || 'Unknown',
        magicDNSEnabled: statusJson.CurrentTailnet?.MagicDNSSuffix ? true : false,
      };

      this._lastCheck = now;
      return this._status;
    } catch (error) {
      console.log('[Tailscale] Failed to get status:', error.message);
      this._status = null;
      return null;
    }
  }

  /**
   * Get just the Tailscale IP (quick check)
   */
  async getIP() {
    const status = await this.getStatus();
    return status?.ip || null;
  }

  /**
   * Get the MagicDNS hostname
   */
  async getMagicDNSHostname() {
    const status = await this.getStatus();
    return status?.magicDNSHostname || null;
  }

  /**
   * Get connection URL via Tailscale
   */
  async getConnectionUrl(port) {
    const ip = await this.getIP();
    if (!ip) return null;
    return `http://${ip}:${port}`;
  }

  /**
   * Invalidate cache (force refresh on next call)
   */
  invalidateCache() {
    this._lastCheck = 0;
    this._status = null;
  }
}

// Singleton
const tailscaleManager = new TailscaleManager();

export { TailscaleManager, tailscaleManager };
