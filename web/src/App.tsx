import './App.css'
import { ConfettiAnimation } from './components/ConfettiAnimation'
import { Footer } from './components/Footer'
import { Header } from './components/Header'
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'

function App() {
  return (
    <Router>
      <div className="app">
        <div className="app-container">
          {/* 页头 */}
          <Header />

          {/* 路由配置 */}
          <Routes>
            <Route path="/" element={
              <>
                {/* Hero区域 */}
                <section className="hero">
                  {/* Confetti 动画背景 */}
                  <div className="confetti-background">
                    <ConfettiAnimation />
                  </div>
                  
                  <div className="awards">
                    <div className="product-hunt-badge">
                      <img src="/product-hunt-award.png" alt="Product Hunt Award" style={{ height: 48 }} />
                    </div>
                    <button className="whats-new-btn">
                      What's new in Clipboard 1.29 →
                    </button>
                  </div>
                  
                  <h1 className="main-title">Clipboard history for Mac</h1>
                  <p className="description">
                    Keep everything you copy and quickly access your macOS clipboard history whenever you need it.
                  </p>
                  
                  <div className="download-buttons">
                    <button className="primary-download-btn">
                      <svg className="apple-icon" width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                      </svg>
                      Download for Apple Silicon
                    </button>
                  </div>
                  
                  <div className="download-options">
                    <span>macOS 14.0+</span>
                    <span className="separator">|</span>
                    <span>Install via Homebrew</span>
                    <span className="separator">|</span>
                    <span>Other options</span>
                  </div>
                  
                  <div className="social-proof">
                    <div className="avatars">
                      <div className="avatar avatar-1"></div>
                      <div className="avatar avatar-2"></div>
                      <div className="avatar avatar-3"></div>
                      <div className="avatar avatar-4"></div>
                      <div className="avatar avatar-5"></div>
                      <div className="avatar avatar-6"></div>
                      <div className="avatar avatar-7"></div>
                    </div>
                    <span><strong>2K+</strong> active users</span>
                  </div>
                </section>

                {/* 核心功能展示 */}
                <section className="core-features">
                  <div className="feature-card">
                    <div className="feature-content">
                      <h3>Full preview & details</h3>
                      <p>Quickly preview the full content of each item in your clipboard history to locate the right one before pasting it. Press ⌘P to show/hide preview pane.</p>
                    </div>
                    <div className="feature-visual">
                      <div className="preview-demo">
                        <div className="demo-header">
                          <div className="demo-dot red"></div>
                          <div className="demo-dot yellow"></div>
                          <div className="demo-dot green"></div>
                        </div>
                        <div className="demo-content">
                          <div className="demo-text">Sample clipboard content...</div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="feature-card reverse">
                    <div className="feature-content">
                      <h3>Quick paste</h3>
                      <p>Paste any of the first 9 items from the history using the ⌘1..9 keyboard shortcuts. Hold ⌘ to show the numbers.</p>
                    </div>
                    <div className="feature-visual">
                      <div className="keyboard-demo">
                        <div className="key">⌘</div>
                        <div className="key">1</div>
                        <div className="key">2</div>
                        <div className="key">3</div>
                      </div>
                    </div>
                  </div>

                  <div className="feature-card">
                    <div className="feature-content">
                      <h3>Global shortcut</h3>
                      <p>Your clipboard history is always at your hands. Press Shift + ⌘ + V to open your macOS clipboard history instantly.</p>
                    </div>
                    <div className="feature-visual">
                      <div className="shortcut-demo">
                        <div className="key">⇧</div>
                        <div className="key">⌘</div>
                        <div className="key">V</div>
                      </div>
                    </div>
                  </div>
                </section>

                {/* 用户评价 */}
                <section className="testimonials">
                  <div className="section-header">
                    <h2>What users say</h2>
                  </div>
                  
                  <div className="testimonial-grid">
                    <div className="testimonial-card">
                      <div className="stars">★★★★★</div>
                      <p>"Clipboard is an incredible app with an incredible UI and I hope to use it a lot more in the future."</p>
                      <div className="testimonial-author">Tad Jimenez</div>
                    </div>
                    
                    <div className="testimonial-card">
                      <div className="stars">★★★★★</div>
                      <p>"Thanks for making Clipboard! It really is amazing — both the product and the website."</p>
                      <div className="testimonial-author">Yuvraj Sarda</div>
                    </div>
                    
                    <div className="testimonial-card">
                      <div className="stars">★★★★★</div>
                      <p>"I've been using your app and to be honest, it's great! Thank you very much."</p>
                      <div className="testimonial-author">Mauricio</div>
                    </div>
                  </div>
                </section>

                {/* 底部下载区域 */}
                <section className="bottom-download">
                  <h2>Never lose what you copy</h2>
                  <p>Keep your copy history, organize it, quickly find what you need and paste it directly to the active app.</p>
                  <button className="primary-download-btn large">
                    <svg className="apple-icon" width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                    </svg>
                    Download for Mac
                  </button>
                </section>
              </>
            } />
          </Routes>
          
          {/* 页脚 */}
          <Footer />
        </div>
      </div>
    </Router>
  )
}

export default App
