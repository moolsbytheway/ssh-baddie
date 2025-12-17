// go-backend/internal/api/terminal.go - new file
package api

import (
	"encoding/json"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"golang.org/x/crypto/ssh"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
}

func (h *Handler) TerminalWebSocket(c *gin.Context) {
	sessionID := c.Param("session_id")

	session, err := h.sessionManager.GetSession(sessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	ws, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("Failed to upgrade WebSocket: %v", err)
		return
	}
	defer ws.Close()

	// Create SSH session with PTY
	sshSession, err := session.Client.NewSession()
	if err != nil {
		log.Printf("Failed to create SSH session: %v", err)
		return
	}
	defer sshSession.Close()

	// Request PTY
	modes := ssh.TerminalModes{
		ssh.ECHO:          1,
		ssh.TTY_OP_ISPEED: 14400,
		ssh.TTY_OP_OSPEED: 14400,
	}

	if err := sshSession.RequestPty("xterm-256color", 40, 80, modes); err != nil {
		log.Printf("Request PTY failed: %v", err)
		return
	}

	// Get stdin/stdout/stderr pipes
	stdin, err := sshSession.StdinPipe()
	if err != nil {
		log.Printf("Failed to get stdin: %v", err)
		return
	}

	stdout, err := sshSession.StdoutPipe()
	if err != nil {
		log.Printf("Failed to get stdout: %v", err)
		return
	}

	stderr, err := sshSession.StderrPipe()
	if err != nil {
		log.Printf("Failed to get stderr: %v", err)
		return
	}

	// Start shell
	if err := sshSession.Shell(); err != nil {
		log.Printf("Failed to start shell: %v", err)
		return
	}

	// Channel to signal completion
	done := make(chan struct{})

	// Read from SSH stdout and send to WebSocket
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stdout.Read(buf)
			if err != nil {
				if err != io.EOF {
					log.Printf("Error reading stdout: %v", err)
				}
				close(done)
				return
			}
			if n > 0 {
				if err := ws.WriteMessage(websocket.TextMessage, buf[:n]); err != nil {
					log.Printf("Error writing to WebSocket: %v", err)
					close(done)
					return
				}
			}
		}
	}()

	// Read from SSH stderr and send to WebSocket
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stderr.Read(buf)
			if err != nil {
				if err != io.EOF {
					log.Printf("Error reading stderr: %v", err)
				}
				return
			}
			if n > 0 {
				if err := ws.WriteMessage(websocket.TextMessage, buf[:n]); err != nil {
					log.Printf("Error writing stderr to WebSocket: %v", err)
					return
				}
			}
		}
	}()

	// Read from WebSocket and send to SSH stdin
	go func() {
		for {
			_, message, err := ws.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					log.Printf("WebSocket error: %v", err)
				}
				stdin.Close()
				return
			}

			// Check if it's a resize message
			var resizeMsg struct {
				Type string `json:"type"`
				Cols int    `json:"cols"`
				Rows int    `json:"rows"`
			}
			if err := json.Unmarshal(message, &resizeMsg); err == nil && resizeMsg.Type == "resize" {
				// Handle terminal resize
				sshSession.WindowChange(resizeMsg.Rows, resizeMsg.Cols)
				continue
			}

			// Regular input
			if _, err := stdin.Write(message); err != nil {
				log.Printf("Error writing to stdin: %v", err)
				return
			}
		}
	}()

	// Wait for completion
	<-done
	sshSession.Wait()
}
