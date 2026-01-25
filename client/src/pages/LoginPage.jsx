import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Html5Qrcode } from 'html5-qrcode';
import styles from './LoginPage.module.css';

export default function LoginPage() {
  const [serverUrl, setServerUrl] = useState(() => {
    // Default to current host if not localhost
    if (window.location.hostname !== 'localhost' || window.location.port === '3847') {
      return `${window.location.protocol}//${window.location.host}`;
    }
    return '';
  });
  const [token, setToken] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [showScanner, setShowScanner] = useState(false);
  const [scannerError, setScannerError] = useState('');
  
  const scannerRef = useRef(null);
  const html5QrCodeRef = useRef(null);
  
  const { login } = useAuth();
  const navigate = useNavigate();

  // Cleanup scanner on unmount
  useEffect(() => {
    return () => {
      if (html5QrCodeRef.current) {
        html5QrCodeRef.current.stop().catch(() => {});
      }
    };
  }, []);

  async function startScanner() {
    setShowScanner(true);
    setScannerError('');
    
    // Wait for DOM to update
    await new Promise(resolve => setTimeout(resolve, 100));
    
    try {
      html5QrCodeRef.current = new Html5Qrcode('qr-reader');
      
      await html5QrCodeRef.current.start(
        { facingMode: 'environment' },
        {
          fps: 10,
          qrbox: { width: 250, height: 250 }
        },
        onQrCodeSuccess,
        onQrCodeError
      );
    } catch (err) {
      console.error('Scanner error:', err);
      setScannerError(
        err.message?.includes('Permission') 
          ? 'Camera permission denied. Please allow camera access.'
          : 'Could not start camera. Try manual entry instead.'
      );
    }
  }

  async function stopScanner() {
    if (html5QrCodeRef.current) {
      try {
        await html5QrCodeRef.current.stop();
      } catch (e) {
        // Ignore stop errors
      }
      html5QrCodeRef.current = null;
    }
    setShowScanner(false);
  }

  async function onQrCodeSuccess(decodedText) {
    try {
      // Parse the QR code data
      const data = JSON.parse(decodedText);
      
      if (data.url && data.token) {
        // Stop scanner first
        await stopScanner();
        
        // Auto-fill and connect
        setServerUrl(data.url);
        setToken(data.token);
        
        // Attempt to connect
        setIsLoading(true);
        setError('');
        
        const result = await login(data.url, data.token);
        
        if (result.success) {
          navigate('/');
        } else {
          setError(result.error || 'Connection failed');
        }
        
        setIsLoading(false);
      }
    } catch (err) {
      console.error('QR parse error:', err);
      setScannerError('Invalid QR code. Please scan the code from the server.');
    }
  }

  function onQrCodeError(error) {
    // Ignore scan errors (they happen constantly while scanning)
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setIsLoading(true);
    
    try {
      const url = serverUrl || `${window.location.protocol}//${window.location.host}`;
      const result = await login(url, token);
      
      if (result.success) {
        navigate('/');
      } else {
        setError(result.error);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }

  if (showScanner) {
    return (
      <div className={styles.container}>
        <div className={styles.scannerCard}>
          <div className={styles.scannerHeader}>
            <h2>Scan QR Code</h2>
            <button className={styles.closeButton} onClick={stopScanner}>
              ✕
            </button>
          </div>
          
          <p className={styles.scannerHint}>
            Point your camera at the QR code displayed on your laptop
          </p>
          
          <div className={styles.scannerWrapper}>
            <div id="qr-reader" className={styles.scanner} ref={scannerRef}></div>
          </div>
          
          {scannerError && (
            <div className={styles.scannerError}>
              {scannerError}
            </div>
          )}
          
          <button 
            className={styles.manualButton}
            onClick={stopScanner}
          >
            Enter manually instead
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <div className={styles.card}>
        <div className={styles.logo}>
          <span className={styles.logoIcon}>⌨️</span>
          <h1 className={styles.title}>Cursor Mobile</h1>
          <p className={styles.subtitle}>Control Cursor from your phone</p>
        </div>
        
        <button 
          className={styles.scanButton}
          onClick={startScanner}
        >
          <span className={styles.scanIcon}>📷</span>
          Scan QR Code to Connect
        </button>
        
        <div className={styles.divider}>
          <span>or enter manually</span>
        </div>
        
        <form onSubmit={handleSubmit} className={styles.form}>
          <div className={styles.field}>
            <label className={styles.label}>Server URL</label>
            <input
              type="url"
              value={serverUrl}
              onChange={(e) => setServerUrl(e.target.value)}
              placeholder="http://192.168.1.100:3847"
              className={styles.input}
              autoComplete="url"
            />
            <p className={styles.hint}>
              Leave empty if accessing via the server directly
            </p>
          </div>
          
          <div className={styles.field}>
            <label className={styles.label}>Auth Token</label>
            <input
              type="password"
              value={token}
              onChange={(e) => setToken(e.target.value)}
              placeholder="Enter your authentication token"
              className={styles.input}
              required
              autoComplete="current-password"
            />
            <p className={styles.hint}>
              Token is displayed when starting the server
            </p>
          </div>
          
          {error && (
            <div className={styles.error}>
              {error}
            </div>
          )}
          
          <button 
            type="submit" 
            className={styles.button}
            disabled={isLoading || !token}
          >
            {isLoading ? 'Connecting...' : 'Connect'}
          </button>
        </form>
        
        <div className={styles.help}>
          <h3>Quick Start</h3>
          <ol>
            <li>Run <code>npm start</code> in the server folder on your laptop</li>
            <li>Scan the QR code displayed in the terminal</li>
            <li>Or enter the URL and token manually</li>
          </ol>
        </div>
      </div>
    </div>
  );
}
