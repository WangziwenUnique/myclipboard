import React from 'react';
import './Footer.css';

export const Footer: React.FC = () => {
  return (
    <footer className="footer">
      <div className="footer-container">
        <div className="footer-left">
          <div className="footer-logo">
            <div className="footer-logo-icon">
              <img src="/logo.svg" alt="Clipboard Logo" width="24" height="24" />
            </div>
            <span>Clipboard</span>
          </div>
          <p className="footer-description">
            Keep everything you copy and quickly access your macOS clipboard history whenever you need it.
          </p>
          <p className="footer-copyright">
            © 2025 Clipboard. All rights reserved.
          </p>
        </div>
        
        <div className="footer-right">
          <div className="footer-columns">
            <div className="footer-column">
              <h4>Product</h4>
              <ul>
                <li><a href="#download">Download</a></li>
                <li><a href="#changelog">Changelog</a></li>
                <li><a href="#roadmap">Roadmap</a></li>
                <li><a href="#pricing">Pricing</a></li>
                <li><a href="#howto">How To</a></li>
                <li><a href="#blog">Blog</a></li>
              </ul>
            </div>
            
            <div className="footer-column">
              <h4>Social</h4>
              <ul>
                <li><a href="https://github.com" target="_blank" rel="noopener noreferrer">GitHub</a></li>
                <li><a href="https://producthunt.com" target="_blank" rel="noopener noreferrer">Product Hunt</a></li>
                <li><a href="#tool-finder">Tool Finder</a></li>
                <li><a href="#startup-fame">Startup Fame</a></li>
                <li><a href="https://linkedin.com" target="_blank" rel="noopener noreferrer">LinkedIn</a></li>
                <li><a href="https://youtube.com" target="_blank" rel="noopener noreferrer">YouTube</a></li>
                <li><a href="https://twitter.com" target="_blank" rel="noopener noreferrer">Twitter/X</a></li>
              </ul>
            </div>
            
            <div className="footer-column">
              <h4>About</h4>
              <ul>
                <li><a href="#contacts">Contacts</a></li>
                <li><a href="#brand-kit">Brand Kit</a></li>
                <li><a href="#privacy">Privacy Policy</a></li>
                <li><a href="#terms">Terms of Use</a></li>
              </ul>
            </div>
            
            <div className="footer-column">
              <h4>Support</h4>
              <ul>
                <li><a href="#feature-request">Request a feature</a></li>
                <li><a href="#bug-report">Report a bug</a></li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </footer>
  );
};
