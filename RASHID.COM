import { useState, useRef, useEffect } from "react";

const TOOLS = [
  { id: "chat", icon: "💬", label: "Chat", color: "#00f5d4", desc: "Talk to AI freely" },
  { id: "summarize", icon: "📄", label: "Summarizer", color: "#f72585", desc: "Condense any text" },
  { id: "improve", icon: "✨", label: "Polish", color: "#ffd60a", desc: "Elevate your writing" },
  { id: "analyze", icon: "🔍", label: "Analyze", color: "#7b2fff", desc: "Deep text insights" },
  { id: "translate", icon: "🌐", label: "Translate", color: "#ff6b35", desc: "Any language" },
  { id: "brainstorm", icon: "⚡", label: "Brainstorm", color: "#00b4d8", desc: "Idea generation" },
];

const SYSTEM_PROMPTS = {
  chat: "You are a brilliant, witty, and helpful AI assistant. Be concise yet insightful.",
  summarize: "You are an expert summarizer. Condense the given text into clear, punchy bullet points with a 1-sentence TL;DR at the top. Be ruthlessly concise.",
  improve: "You are a world-class editor. Rewrite the given text to be more polished, clear, and compelling. Keep the original meaning but elevate the language. Show the improved version only.",
  analyze: "You are a sharp analyst. Analyze the given text and provide: tone, key themes, sentiment, writing style, and 2-3 interesting observations. Be insightful and specific.",
  translate: "You are a professional translator. The user will specify a target language followed by the text. Translate accurately and naturally, preserving tone and nuance.",
  brainstorm: "You are a creative genius. Generate 8-10 fresh, diverse, and actionable ideas based on the user's topic. Make them specific, not generic. Format as a numbered list.",
};

const PLACEHOLDERS = {
  chat: "Ask me anything...",
  summarize: "Paste any text to summarize...",
  improve: "Paste your writing to polish it...",
  analyze: "Paste text to analyze...",
  translate: "Start with your target language, e.g. 'French: Hello world'",
  brainstorm: "Enter a topic to brainstorm ideas for...",
};

function TypingIndicator() {
  return (
    <div style={{ display: "flex", gap: 5, alignItems: "center", padding: "12px 16px" }}>
      {[0, 1, 2].map((i) => (
        <div
          key={i}
          style={{
            width: 8,
            height: 8,
            borderRadius: "50%",
            background: "#00f5d4",
            animation: `bounce 1.2s ease-in-out ${i * 0.2}s infinite`,
          }}
        />
      ))}
    </div>
  );
}

export default function AISwissArmyKnife() {
  const [activeTool, setActiveTool] = useState("chat");
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState({ chat: [] });
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState({});
  const outputRef = useRef(null);
  const textareaRef = useRef(null);

  const tool = TOOLS.find((t) => t.id === activeTool);

  useEffect(() => {
    if (outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight;
    }
  }, [messages, results, loading]);

  const handleRun = async () => {
    if (!input.trim() || loading) return;
    const userInput = input.trim();
    setInput("");
    setLoading(true);

    if (activeTool === "chat") {
      const newMessages = [...(messages.chat || []), { role: "user", content: userInput }];
      setMessages((prev) => ({ ...prev, chat: newMessages }));

      try {
        const response = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            model: "claude-sonnet-4-20250514",
            max_tokens: 1000,
            system: SYSTEM_PROMPTS.chat,
            messages: newMessages,
          }),
        });
        const data = await response.json();
        const reply = data.content?.[0]?.text || "Sorry, something went wrong.";
        setMessages((prev) => ({
          ...prev,
          chat: [...newMessages, { role: "assistant", content: reply }],
        }));
      } catch {
        setMessages((prev) => ({
          ...prev,
          chat: [...newMessages, { role: "assistant", content: "Error connecting to AI." }],
        }));
      }
    } else {
      try {
        const response = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            model: "claude-sonnet-4-20250514",
            max_tokens: 1000,
            system: SYSTEM_PROMPTS[activeTool],
            messages: [{ role: "user", content: userInput }],
          }),
        });
        const data = await response.json();
        const reply = data.content?.[0]?.text || "Sorry, something went wrong.";
        setResults((prev) => ({ ...prev, [activeTool]: { input: userInput, output: reply } }));
      } catch {
        setResults((prev) => ({ ...prev, [activeTool]: { input: userInput, output: "Error connecting to AI." } }));
      }
    }
    setLoading(false);
  };

  const handleKey = (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleRun();
    }
  };

  const switchTool = (id) => {
    setActiveTool(id);
    setInput("");
    setTimeout(() => textareaRef.current?.focus(), 100);
  };

  const chatMessages = messages.chat || [];
  const result = results[activeTool];

  return (
    <div style={{
      minHeight: "100vh",
      background: "#080b14",
      fontFamily: "'DM Mono', 'Courier New', monospace",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      padding: "32px 16px",
      color: "#e8eaf0",
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Mono:wght@300;400;500&family=Syne:wght@700;800&display=swap');
        @keyframes bounce { 0%,60%,100%{transform:translateY(0)} 30%{transform:translateY(-8px)} }
        @keyframes fadeIn { from{opacity:0;transform:translateY(8px)} to{opacity:1;transform:translateY(0)} }
        @keyframes glow { 0%,100%{opacity:0.5} 50%{opacity:1} }
        * { box-sizing: border-box; }
        ::-webkit-scrollbar { width: 4px; }
        ::-webkit-scrollbar-track { background: #111420; }
        ::-webkit-scrollbar-thumb { background: #2a2f45; border-radius: 2px; }
        textarea:focus { outline: none; }
        button { cursor: pointer; border: none; }
      `}</style>

      {/* Header */}
      <div style={{ textAlign: "center", marginBottom: 36 }}>
        <div style={{
          fontSize: 11,
          letterSpacing: 6,
          color: "#00f5d4",
          marginBottom: 10,
          textTransform: "uppercase",
          animation: "glow 3s ease-in-out infinite",
        }}>
          ◈ POWERED BY CLAUDE ◈
        </div>
        <h1 style={{
          fontFamily: "'Syne', sans-serif",
          fontSize: "clamp(28px, 5vw, 52px)",
          fontWeight: 800,
          margin: 0,
          lineHeight: 1,
          background: "linear-gradient(135deg, #fff 0%, #00f5d4 50%, #7b2fff 100%)",
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
          backgroundClip: "text",
        }}>
          AI TOOLKIT
        </h1>
        <p style={{ color: "#5a6080", fontSize: 13, marginTop: 8, letterSpacing: 1 }}>
          Six AI superpowers. One interface.
        </p>
      </div>

      {/* Tool Selector */}
      <div style={{
        display: "flex",
        gap: 8,
        flexWrap: "wrap",
        justifyContent: "center",
        marginBottom: 28,
        maxWidth: 700,
      }}>
        {TOOLS.map((t) => (
          <button
            key={t.id}
            onClick={() => switchTool(t.id)}
            style={{
              padding: "8px 16px",
              borderRadius: 6,
              background: activeTool === t.id ? t.color : "transparent",
              color: activeTool === t.id ? "#080b14" : "#5a6080",
              border: `1px solid ${activeTool === t.id ? t.color : "#1e2336"}`,
              fontSize: 12,
              fontFamily: "'DM Mono', monospace",
              fontWeight: activeTool === t.id ? 500 : 400,
              letterSpacing: 1,
              transition: "all 0.2s ease",
              display: "flex",
              alignItems: "center",
              gap: 6,
            }}
          >
            <span>{t.icon}</span>
            <span style={{ textTransform: "uppercase" }}>{t.label}</span>
          </button>
        ))}
      </div>

      {/* Main Panel */}
      <div style={{
        width: "100%",
        maxWidth: 720,
        background: "#0d1120",
        border: `1px solid ${tool.color}22`,
        borderRadius: 12,
        overflow: "hidden",
        boxShadow: `0 0 60px ${tool.color}10, 0 0 0 1px ${tool.color}15`,
      }}>
        {/* Panel Header */}
        <div style={{
          padding: "14px 20px",
          borderBottom: `1px solid ${tool.color}20`,
          display: "flex",
          alignItems: "center",
          gap: 10,
          background: `linear-gradient(90deg, ${tool.color}08 0%, transparent 100%)`,
        }}>
          <span style={{ fontSize: 18 }}>{tool.icon}</span>
          <div>
            <div style={{ fontSize: 13, fontWeight: 500, color: tool.color, letterSpacing: 2, textTransform: "uppercase" }}>
              {tool.label}
            </div>
            <div style={{ fontSize: 11, color: "#3a4060", letterSpacing: 1 }}>{tool.desc}</div>
          </div>
          <div style={{ marginLeft: "auto", display: "flex", gap: 6 }}>
            {["#ff5f57", "#febc2e", "#28c840"].map((c) => (
              <div key={c} style={{ width: 10, height: 10, borderRadius: "50%", background: c, opacity: 0.7 }} />
            ))}
          </div>
        </div>

        {/* Output Area */}
        <div
          ref={outputRef}
          style={{
            minHeight: 280,
            maxHeight: 360,
            overflowY: "auto",
            padding: activeTool === "chat" ? "0" : "20px",
          }}
        >
          {activeTool === "chat" ? (
            <div style={{ padding: "8px 0" }}>
              {chatMessages.length === 0 && (
                <div style={{
                  textAlign: "center",
                  padding: "60px 20px",
                  color: "#2a3050",
                  fontSize: 13,
                  letterSpacing: 1,
                }}>
                  <div style={{ fontSize: 32, marginBottom: 12 }}>💬</div>
                  Start a conversation...
                </div>
              )}
              {chatMessages.map((msg, i) => (
                <div
                  key={i}
                  style={{
                    padding: "14px 20px",
                    animation: "fadeIn 0.3s ease",
                    background: msg.role === "user" ? `${tool.color}06` : "transparent",
                    borderLeft: msg.role === "assistant" ? `2px solid ${tool.color}40` : "2px solid transparent",
                  }}
                >
                  <div style={{
                    fontSize: 10,
                    color: msg.role === "user" ? tool.color : "#3a4060",
                    marginBottom: 6,
                    letterSpacing: 2,
                    textTransform: "uppercase",
                  }}>
                    {msg.role === "user" ? "▶ YOU" : "◈ CLAUDE"}
                  </div>
                  <div style={{
                    fontSize: 14,
                    lineHeight: 1.7,
                    color: msg.role === "user" ? "#c8cce0" : "#e8eaf0",
                    whiteSpace: "pre-wrap",
                  }}>
                    {msg.content}
                  </div>
                </div>
              ))}
              {loading && activeTool === "chat" && (
                <div style={{ padding: "0 20px" }}>
                  <div style={{ fontSize: 10, color: "#3a4060", marginBottom: 4, letterSpacing: 2 }}>◈ CLAUDE</div>
                  <TypingIndicator />
                </div>
              )}
            </div>
          ) : (
            <div>
              {!result && !loading && (
                <div style={{
                  textAlign: "center",
                  padding: "60px 20px",
                  color: "#2a3050",
                  fontSize: 13,
                  letterSpacing: 1,
                }}>
                  <div style={{ fontSize: 32, marginBottom: 12 }}>{tool.icon}</div>
                  {tool.desc}. Enter text below to begin.
                </div>
              )}
              {loading && (
                <div style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 12,
                  color: "#3a4060",
                  fontSize: 13,
                  padding: "40px 20px",
                }}>
                  <TypingIndicator />
                  <span style={{ letterSpacing: 1 }}>Processing...</span>
                </div>
              )}
              {result && !loading && (
                <div style={{ animation: "fadeIn 0.4s ease" }}>
                  <div style={{
                    fontSize: 10,
                    color: "#3a4060",
                    letterSpacing: 2,
                    marginBottom: 10,
                    textTransform: "uppercase",
                  }}>◈ Result</div>
                  <div style={{
                    fontSize: 14,
                    lineHeight: 1.8,
                    color: "#d8daf0",
                    whiteSpace: "pre-wrap",
                    background: `${tool.color}06`,
                    border: `1px solid ${tool.color}18`,
                    borderRadius: 8,
                    padding: 16,
                  }}>
                    {result.output}
                  </div>
                  <button
                    onClick={() => navigator.clipboard?.writeText(result.output)}
                    style={{
                      marginTop: 10,
                      padding: "6px 14px",
                      background: "transparent",
                      border: `1px solid ${tool.color}30`,
                      borderRadius: 4,
                      color: tool.color,
                      fontSize: 11,
                      fontFamily: "'DM Mono', monospace",
                      letterSpacing: 1,
                    }}
                  >
                    ⎘ COPY
                  </button>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Input Area */}
        <div style={{
          borderTop: `1px solid ${tool.color}15`,
          padding: "16px 20px",
          background: "#080b14",
        }}>
          <div style={{
            display: "flex",
            gap: 12,
            alignItems: "flex-end",
          }}>
            <textarea
              ref={textareaRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKey}
              placeholder={PLACEHOLDERS[activeTool]}
              rows={2}
              style={{
                flex: 1,
                background: "#0d1120",
                border: `1px solid ${input ? tool.color + "40" : "#1e2336"}`,
                borderRadius: 8,
                padding: "12px 14px",
                color: "#e8eaf0",
                fontSize: 13,
                fontFamily: "'DM Mono', monospace",
                resize: "none",
                lineHeight: 1.6,
                transition: "border-color 0.2s ease",
              }}
            />
            <button
              onClick={handleRun}
              disabled={!input.trim() || loading}
              style={{
                padding: "12px 20px",
                background: input.trim() && !loading ? tool.color : "#1e2336",
                color: input.trim() && !loading ? "#080b14" : "#3a4060",
                borderRadius: 8,
                fontSize: 12,
                fontFamily: "'DM Mono', monospace",
                fontWeight: 500,
                letterSpacing: 1,
                transition: "all 0.2s ease",
                whiteSpace: "nowrap",
              }}
            >
              {loading ? "..." : "RUN ▶"}
            </button>
          </div>
          <div style={{
            marginTop: 8,
            fontSize: 10,
            color: "#2a3050",
            letterSpacing: 1,
          }}>
            ENTER to send · SHIFT+ENTER for new line
          </div>
        </div>
      </div>

      {/* Tool grid hints */}
      <div style={{
        display: "flex",
        gap: 8,
        flexWrap: "wrap",
        justifyContent: "center",
        marginTop: 24,
        maxWidth: 720,
      }}>
        {TOOLS.filter((t) => t.id !== activeTool).map((t) => (
          <button
            key={t.id}
            onClick={() => switchTool(t.id)}
            style={{
              padding: "5px 12px",
              background: "transparent",
              border: "1px solid #1a1f32",
              borderRadius: 4,
              color: "#2a3050",
              fontSize: 11,
              fontFamily: "'DM Mono', monospace",
              letterSpacing: 1,
              transition: "all 0.2s ease",
            }}
            onMouseEnter={(e) => { e.target.style.color = t.color; e.target.style.borderColor = t.color + "40"; }}
            onMouseLeave={(e) => { e.target.style.color = "#2a3050"; e.target.style.borderColor = "#1a1f32"; }}
          >
            {t.icon} {t.label.toUpperCase()}
          </button>
        ))}
      </div>

      <div style={{
        marginTop: 28,
        fontSize: 10,
        color: "#1e2336",
        letterSpacing: 2,
        textAlign: "center",
      }}>
        ◈ CLAUDE AI · ALL TOOLS POWERED BY ANTHROPIC ◈
      </div>
    </div>
  );
}