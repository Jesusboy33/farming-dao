import React, { useState, useEffect, useRef } from 'react';
import { toast } from 'react-toastify';
import { formatNumber } from '../utils/formatters';

interface Message {
  id: string;
  text: string;
  isBot: boolean;
  timestamp: Date;
  type?: 'text' | 'recommendation' | 'analysis' | 'warning';
}

interface TradingRecommendation {
  action: 'buy' | 'sell' | 'hold';
  confidence: number;
  reasoning: string;
  suggestedAmount?: number;
  targetPrice?: number;
  stopLoss?: number;
}

interface MarketData {
  price: number;
  change24h: number;
  volume24h: number;
  volatility: number;
  trend: 'bullish' | 'bearish' | 'neutral';
}

interface TradingChatbotProps {
  isOpen: boolean;
  onToggle: () => void;
  userAddress: string;
  portfolioData: {
    betterCoinBalance?: number;
  };
}

export const TradingChatbot: React.FC<TradingChatbotProps> = ({
  isOpen,
  onToggle,
  userAddress,
  portfolioData
}) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [marketData, setMarketData] = useState<MarketData | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Mock market data - in production, this would come from real market APIs
  useEffect(() => {
    const fetchMarketData = () => {
      // Simulate market data
      const mockData: MarketData = {
        price: 1.23 + (Math.random() - 0.5) * 0.1,
        change24h: (Math.random() - 0.5) * 20,
        volume24h: 1000000 + Math.random() * 500000,
        volatility: Math.random() * 30,
        trend: Math.random() > 0.6 ? 'bullish' : Math.random() > 0.3 ? 'bearish' : 'neutral'
      };
      setMarketData(mockData);
    };

    fetchMarketData();
    const interval = setInterval(fetchMarketData, 30000); // Update every 30 seconds
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (isOpen && messages.length === 0) {
      addMessage(
        "👋 Hello! I'm your AI Trading Assistant. I can help you with:\n\n" +
        "• Market analysis and trends\n" +
        "• Trading recommendations\n" +
        "• Portfolio optimization\n" +
        "• Risk management advice\n" +
        "• Technical analysis\n\n" +
        "What would you like to know about your trading today?",
        true
      );
    }
  }, [isOpen, messages.length]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const addMessage = (text: string, isBot: boolean, type: Message['type'] = 'text') => {
    const message: Message = {
      id: Date.now().toString(),
      text,
      isBot,
      timestamp: new Date(),
      type
    };
    setMessages(prev => [...prev, message]);
  };

  const generateTradingRecommendation = (query: string): TradingRecommendation => {
    const lowerQuery = query.toLowerCase();
    
    // Analyze market conditions
    const isVolatile = marketData ? marketData.volatility > 20 : false;
    const isBullish = marketData ? marketData.trend === 'bullish' : false;
    const priceChange = marketData ? marketData.change24h : 0;

    // Generate recommendation based on query and market conditions
    if (lowerQuery.includes('buy') || lowerQuery.includes('purchase')) {
      if (isBullish && !isVolatile) {
        return {
          action: 'buy',
          confidence: 75,
          reasoning: 'Market shows bullish trend with low volatility. Good entry opportunity.',
          suggestedAmount: portfolioData.betterCoinBalance ? portfolioData.betterCoinBalance * 0.1 : 100,
          targetPrice: marketData ? marketData.price * 1.15 : 1.4
        };
      } else {
        return {
          action: 'hold',
          confidence: 60,
          reasoning: 'Current market conditions suggest waiting for a better entry point.',
        };
      }
    } else if (lowerQuery.includes('sell')) {
      if (!isBullish || isVolatile) {
        return {
          action: 'sell',
          confidence: 70,
          reasoning: 'Market shows bearish signals or high volatility. Consider taking profits.',
          stopLoss: marketData ? marketData.price * 0.9 : 1.0
        };
      } else {
        return {
          action: 'hold',
          confidence: 65,
          reasoning: 'Market still shows strength. Consider holding for higher targets.',
        };
      }
    } else {
      return {
        action: 'hold',
        confidence: 50,
        reasoning: 'Market analysis suggests maintaining current position while monitoring key levels.',
      };
    }
  };

  const analyzeMarket = (): string => {
    if (!marketData) {
      return "Market data is currently unavailable. Please try again in a moment.";
    }

    const { price, change24h, volume24h, volatility, trend } = marketData;
    
    let analysis = `📊 **Current Market Analysis for BetterCoin (BETT)**\n\n`;
    analysis += `💰 **Price**: $${price.toFixed(4)}\n`;
    analysis += `📈 **24h Change**: ${change24h > 0 ? '+' : ''}${change24h.toFixed(2)}%\n`;
    analysis += `📊 **24h Volume**: $${formatNumber(volume24h)}\n`;
    analysis += `⚡ **Volatility**: ${volatility.toFixed(1)}%\n`;
    analysis += `📋 **Trend**: ${trend.charAt(0).toUpperCase() + trend.slice(1)}\n\n`;

    // Technical analysis
    if (volatility > 25) {
      analysis += `⚠️ **High Volatility Alert**: Current volatility is ${volatility.toFixed(1)}%, indicating increased risk. Consider smaller position sizes.\n\n`;
    }

    if (Math.abs(change24h) > 10) {
      analysis += `🚨 **Significant Move**: ${change24h > 0 ? 'Strong upward' : 'Strong downward'} movement detected. Monitor for continuation or reversal signals.\n\n`;
    }

    // Trend analysis
    switch (trend) {
      case 'bullish':
        analysis += `🐂 **Bullish Signals**: Market shows positive momentum. Consider accumulating on dips.\n`;
        break;
      case 'bearish':
        analysis += `🐻 **Bearish Signals**: Market shows weakness. Exercise caution and consider risk management.\n`;
        break;
      default:
        analysis += `😐 **Neutral Market**: No clear direction. Wait for breakout signals before making major moves.\n`;
    }

    return analysis;
  };

  const getPortfolioAnalysis = (): string => {
    const balance = portfolioData.betterCoinBalance || 0;
    const currentValue = marketData ? balance * marketData.price : balance;
    
    let analysis = `🎯 **Portfolio Analysis**\n\n`;
    analysis += `💎 **BETT Holdings**: ${formatNumber(balance)} BETT\n`;
    analysis += `💰 **Current Value**: $${formatNumber(currentValue)}\n\n`;

    if (balance > 0) {
      analysis += `📈 **Recommendations**:\n`;
      if (marketData && marketData.trend === 'bullish') {
        analysis += `• Consider staking your BETT for yield farming rewards\n`;
        analysis += `• Set stop-loss at ${(marketData.price * 0.85).toFixed(4)} to protect gains\n`;
      } else {
        analysis += `• Monitor market conditions for optimal exit points\n`;
        analysis += `• Consider diversifying into liquidity pools for yield\n`;
      }
    } else {
      analysis += `💡 **Suggestion**: Consider starting with a small position to begin building your BETT portfolio.\n`;
    }

    return analysis;
  };

  const processMessage = async (message: string) => {
    setIsLoading(true);
    
    try {
      const lowerMessage = message.toLowerCase();
      let response = '';
      let messageType: Message['type'] = 'text';

      if (lowerMessage.includes('market') || lowerMessage.includes('analysis') || lowerMessage.includes('price')) {
        response = analyzeMarket();
        messageType = 'analysis';
      } else if (lowerMessage.includes('portfolio') || lowerMessage.includes('balance') || lowerMessage.includes('holdings')) {
        response = getPortfolioAnalysis();
        messageType = 'analysis';
      } else if (lowerMessage.includes('buy') || lowerMessage.includes('sell') || lowerMessage.includes('trade')) {
        const recommendation = generateTradingRecommendation(message);
        response = formatRecommendation(recommendation);
        messageType = 'recommendation';
      } else if (lowerMessage.includes('risk') || lowerMessage.includes('danger') || lowerMessage.includes('safe')) {
        response = getRiskAnalysis();
        messageType = 'warning';
      } else if (lowerMessage.includes('help') || lowerMessage.includes('what can')) {
        response = getHelpMessage();
      } else if (lowerMessage.includes('liquidity') || lowerMessage.includes('pool') || lowerMessage.includes('yield')) {
        response = getLiquidityAdvice();
      } else {
        // General AI response
        response = generateGeneralResponse(message);
      }

      // Simulate AI processing time
      await new Promise(resolve => setTimeout(resolve, 1000 + Math.random() * 2000));
      
      addMessage(response, true, messageType);
    } catch (error) {
      console.error('Error processing message:', error);
      addMessage('Sorry, I encountered an error processing your request. Please try again.', true);
      toast.error('Chatbot error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  const formatRecommendation = (rec: TradingRecommendation): string => {
    let response = `🤖 **AI Trading Recommendation**\n\n`;
    response += `📋 **Action**: ${rec.action.toUpperCase()}\n`;
    response += `🎯 **Confidence**: ${rec.confidence}%\n`;
    response += `💭 **Reasoning**: ${rec.reasoning}\n\n`;

    if (rec.suggestedAmount) {
      response += `💰 **Suggested Amount**: ${formatNumber(rec.suggestedAmount)} BETT\n`;
    }
    if (rec.targetPrice) {
      response += `🎯 **Target Price**: $${rec.targetPrice.toFixed(4)}\n`;
    }
    if (rec.stopLoss) {
      response += `🛑 **Stop Loss**: $${rec.stopLoss.toFixed(4)}\n`;
    }

    response += `\n⚠️ *This is AI-generated advice. Always do your own research and never invest more than you can afford to lose.*`;
    
    return response;
  };

  const getRiskAnalysis = (): string => {
    let analysis = `⚠️ **Risk Assessment**\n\n`;
    
    if (marketData) {
      const riskLevel = marketData.volatility > 25 ? 'HIGH' : marketData.volatility > 15 ? 'MEDIUM' : 'LOW';
      analysis += `📊 **Current Risk Level**: ${riskLevel}\n`;
      analysis += `⚡ **Volatility**: ${marketData.volatility.toFixed(1)}%\n\n`;
      
      analysis += `🔒 **Risk Management Tips**:\n`;
      analysis += `• Never invest more than 5-10% of your portfolio in a single asset\n`;
      analysis += `• Set stop-losses to limit potential losses\n`;
      analysis += `• Consider dollar-cost averaging for large positions\n`;
      analysis += `• Diversify across different asset classes\n`;
      
      if (riskLevel === 'HIGH') {
        analysis += `\n🚨 **High Risk Warning**: Current market volatility is elevated. Consider reducing position sizes and increasing cash reserves.`;
      }
    } else {
      analysis += `Unable to assess current risk levels. Please ensure you have proper risk management in place.`;
    }
    
    return analysis;
  };

  const getLiquidityAdvice = (): string => {
    let advice = `🌊 **Liquidity & Yield Farming Advice**\n\n`;
    
    const balance = portfolioData.betterCoinBalance || 0;
    
    if (balance > 0) {
      advice += `💎 **Your BETT Balance**: ${formatNumber(balance)} BETT\n\n`;
      advice += `🚀 **Opportunities**:\n`;
      advice += `• **Liquidity Pools**: Earn fees by providing liquidity\n`;
      advice += `• **Yield Farming**: Stake LP tokens for additional rewards\n`;
      advice += `• **Expected APY**: 15-25% depending on pool utilization\n\n`;
      
      advice += `⚡ **Quick Steps**:\n`;
      advice += `1. Go to the Liquidity tab\n`;
      advice += `2. Add liquidity to BETT/STX pool\n`;
      advice += `3. Stake your LP tokens for farming rewards\n`;
      advice += `4. Monitor and compound your earnings\n\n`;
      
      advice += `💡 **Pro Tip**: Start with a small amount to understand the process before committing larger sums.`;
    } else {
      advice += `To participate in liquidity provision, you'll need some BETT tokens first. Consider acquiring some through our trading interface.`;
    }
    
    return advice;
  };

  const getHelpMessage = (): string => {
    return `🤖 **AI Trading Assistant Help**\n\n` +
           `I can help you with:\n\n` +
           `📊 **Market Analysis**: Ask about "market analysis", "price", or "trends"\n` +
           `💼 **Portfolio**: Ask about "portfolio", "balance", or "holdings"\n` +
           `💰 **Trading**: Ask about "buy", "sell", or trading strategies\n` +
           `⚠️ **Risk Management**: Ask about "risk" or safety measures\n` +
           `🌊 **Liquidity**: Ask about "liquidity pools" or "yield farming"\n\n` +
           `**Example questions**:\n` +
           `• "Should I buy BETT right now?"\n` +
           `• "What's the current market analysis?"\n` +
           `• "How's my portfolio performing?"\n` +
           `• "What are the risks?"\n` +
           `• "How can I earn yield?"\n\n` +
           `Feel free to ask me anything about trading and DeFi!`;
  };

  const generateGeneralResponse = (message: string): string => {
    const responses = [
      `That's an interesting question about ${message.split(' ').slice(0, 3).join(' ')}. Based on current market conditions, I'd recommend staying informed about the latest developments.`,
      `I understand you're asking about trading strategies. The key is to always maintain proper risk management and never invest more than you can afford to lose.`,
      `Thanks for your question! While I can provide general guidance, always remember that cryptocurrency trading involves significant risks. Do your own research!`,
      `That's a great question! For the most accurate and up-to-date information, I recommend checking the latest market data and consulting multiple sources.`
    ];
    
    return responses[Math.floor(Math.random() * responses.length)];
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputValue.trim() || isLoading) return;

    const userMessage = inputValue.trim();
    addMessage(userMessage, false);
    setInputValue('');
    
    processMessage(userMessage);
  };

  const formatMessageText = (text: string) => {
    // Convert markdown-like formatting to HTML
    return text
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.*?)\*/g, '<em>$1</em>')
      .replace(/\n/g, '<br/>');
  };

  if (!isOpen) {
    return null;
  }

  return (
    <div className="trading-chatbot">
      <div className="chatbot-header">
        <div className="chatbot-title">
          <div className="chatbot-avatar">🤖</div>
          <div>
            <h3>AI Trading Assistant</h3>
            <span className="status">
              {isLoading ? 'Thinking...' : 'Online'}
              <div className={`status-indicator ${isLoading ? 'thinking' : 'online'}`}></div>
            </span>
          </div>
        </div>
        <button 
          className="close-button"
          onClick={onToggle}
          title="Close Assistant"
        >
          ✕
        </button>
      </div>

      <div className="chatbot-messages">
        {messages.map((message) => (
          <div 
            key={message.id} 
            className={`message ${message.isBot ? 'bot' : 'user'} ${message.type || 'text'}`}
          >
            <div className="message-content">
              <div 
                className="message-text"
                dangerouslySetInnerHTML={{ 
                  __html: formatMessageText(message.text) 
                }}
              />
              <div className="message-timestamp">
                {message.timestamp.toLocaleTimeString([], { 
                  hour: '2-digit', 
                  minute: '2-digit' 
                })}
              </div>
            </div>
          </div>
        ))}
        {isLoading && (
          <div className="message bot">
            <div className="message-content">
              <div className="typing-indicator">
                <div className="typing-dots">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
              </div>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      <form className="chatbot-input-form" onSubmit={handleSubmit}>
        <input
          ref={inputRef}
          type="text"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          placeholder="Ask me about trading, markets, or your portfolio..."
          disabled={isLoading}
          maxLength={500}
        />
        <button 
          type="submit" 
          disabled={!inputValue.trim() || isLoading}
          title="Send message"
        >
          {isLoading ? '⏳' : '📤'}
        </button>
      </form>

      <div className="quick-actions">
        <button 
          className="quick-action"
          onClick={() => processMessage('market analysis')}
          disabled={isLoading}
        >
          📊 Market Analysis
        </button>
        <button 
          className="quick-action"
          onClick={() => processMessage('portfolio')}
          disabled={isLoading}
        >
          💼 Portfolio
        </button>
        <button 
          className="quick-action"
          onClick={() => processMessage('should I buy')}
          disabled={isLoading}
        >
          💰 Trade Advice
        </button>
      </div>
    </div>
  );
};