import React, { useState, useEffect } from 'react';
import { Connect } from '@stacks/connect-react';
import { AppConfig, UserSession, showConnect } from '@stacks/connect';
import { StacksMainnet, StacksTestnet } from '@stacks/network';
import { Header } from './components/Header';
import { TradingInterface } from './components/TradingInterface';
import { LiquidityInterface } from './components/LiquidityInterface';
import { PortfolioView } from './components/PortfolioView';
import { TradingChatbot } from './components/TradingChatbot';
import { useStacksAuth } from './hooks/useStacksAuth';
import { useContract } from './hooks/useContract';
import { ToastContainer } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import './App.css';

// Configure Stacks network
const appConfig = new AppConfig(['store_write', 'publish_data']);
const userSession = new UserSession({ appConfig });
const network = process.env.REACT_APP_NETWORK === 'mainnet' 
  ? new StacksMainnet() 
  : new StacksTestnet();

interface AppProps {}

const App: React.FC<AppProps> = () => {
  const [activeTab, setActiveTab] = useState<'trade' | 'liquidity' | 'portfolio'>('trade');
  const [isDarkMode, setIsDarkMode] = useState(true);
  const [chatbotOpen, setChatbotOpen] = useState(false);

  const { 
    isAuthenticated, 
    userAddress, 
    authenticate, 
    signOut 
  } = useStacksAuth(userSession);

  const {
    betterCoinBalance,
    refreshBalances,
    isLoading: contractLoading
  } = useContract(userAddress);

  useEffect(() => {
    const savedTheme = localStorage.getItem('bettercoin-theme');
    if (savedTheme) {
      setIsDarkMode(savedTheme === 'dark');
    }
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', isDarkMode ? 'dark' : 'light');
    localStorage.setItem('bettercoin-theme', isDarkMode ? 'dark' : 'light');
  }, [isDarkMode]);

  const handleConnect = () => {
    showConnect({
      appDetails: {
        name: 'BetterCoin DEX',
        icon: `${window.location.origin}/logo512.png`,
      },
      redirectTo: '/',
      onFinish: () => {
        console.log('Authentication successful');
      },
      onCancel: () => {
        console.log('Authentication cancelled');
      },
      userSession,
    });
  };

  const toggleTheme = () => {
    setIsDarkMode(!isDarkMode);
  };

  const toggleChatbot = () => {
    setChatbotOpen(!chatbotOpen);
  };

  return (
    <Connect
      authOptions={{
        appDetails: {
          name: 'BetterCoin DEX',
          icon: `${window.location.origin}/logo512.png`,
        },
        redirectTo: '/',
        onFinish: () => window.location.reload(),
        userSession,
      }}
    >
      <div className={`app ${isDarkMode ? 'dark' : 'light'}`}>
        <Header
          isAuthenticated={isAuthenticated}
          userAddress={userAddress}
          betterCoinBalance={betterCoinBalance}
          onConnect={handleConnect}
          onSignOut={signOut}
          onToggleTheme={toggleTheme}
          isDarkMode={isDarkMode}
          activeTab={activeTab}
          onTabChange={setActiveTab}
        />

        <main className="main-content">
          <div className="container">
            {!isAuthenticated ? (
              <div className="welcome-section">
                <div className="welcome-card">
                  <div className="welcome-icon">
                    <img src="/logo512.png" alt="BetterCoin" className="logo" />
                  </div>
                  <h1>Welcome to BetterCoin DEX</h1>
                  <p>
                    The most advanced decentralized exchange on Stacks with AI-powered trading insights,
                    yield farming, and sophisticated liquidity management.
                  </p>
                  <div className="features-grid">
                    <div className="feature-card">
                      <div className="feature-icon">🔄</div>
                      <h3>Advanced Trading</h3>
                      <p>Limit orders, market making, and price discovery mechanisms</p>
                    </div>
                    <div className="feature-card">
                      <div className="feature-icon">💰</div>
                      <h3>Yield Farming</h3>
                      <p>Earn rewards by providing liquidity to our pools</p>
                    </div>
                    <div className="feature-card">
                      <div className="feature-icon">🤖</div>
                      <h3>AI Trading Advisor</h3>
                      <p>Get intelligent trading recommendations powered by AI</p>
                    </div>
                    <div className="feature-card">
                      <div className="feature-icon">🔒</div>
                      <h3>Secure & Governed</h3>
                      <p>Community-governed with advanced security features</p>
                    </div>
                  </div>
                  <button 
                    className="connect-button primary"
                    onClick={handleConnect}
                  >
                    Connect Wallet to Get Started
                  </button>
                </div>
              </div>
            ) : (
              <>
                <div className="tab-content">
                  {activeTab === 'trade' && (
                    <TradingInterface 
                      userAddress={userAddress}
                      network={network}
                      onRefreshBalances={refreshBalances}
                    />
                  )}
                  {activeTab === 'liquidity' && (
                    <LiquidityInterface 
                      userAddress={userAddress}
                      network={network}
                      onRefreshBalances={refreshBalances}
                    />
                  )}
                  {activeTab === 'portfolio' && (
                    <PortfolioView 
                      userAddress={userAddress}
                      network={network}
                      betterCoinBalance={betterCoinBalance}
                    />
                  )}
                </div>

                {/* AI Trading Chatbot */}
                <div className={`chatbot-container ${chatbotOpen ? 'open' : ''}`}>
                  <TradingChatbot
                    isOpen={chatbotOpen}
                    onToggle={toggleChatbot}
                    userAddress={userAddress}
                    portfolioData={{
                      betterCoinBalance,
                      // Add more portfolio data as needed
                    }}
                  />
                </div>

                {/* Floating Action Button for Chatbot */}
                <button
                  className="chatbot-fab"
                  onClick={toggleChatbot}
                  title="AI Trading Assistant"
                >
                  🤖
                </button>
              </>
            )}
          </div>
        </main>

        {/* Loading Overlay */}
        {contractLoading && (
          <div className="loading-overlay">
            <div className="loading-spinner">
              <div className="spinner"></div>
              <p>Loading...</p>
            </div>
          </div>
        )}

        {/* Toast Notifications */}
        <ToastContainer
          position="bottom-right"
          autoClose={5000}
          hideProgressBar={false}
          newestOnTop
          closeOnClick
          rtl={false}
          pauseOnFocusLoss
          draggable
          pauseOnHover
          theme={isDarkMode ? 'dark' : 'light'}
        />

        {/* Background Effects */}
        <div className="background-effects">
          <div className="gradient-orb orb-1"></div>
          <div className="gradient-orb orb-2"></div>
          <div className="gradient-orb orb-3"></div>
        </div>
      </div>
    </Connect>
  );
};

export default App;