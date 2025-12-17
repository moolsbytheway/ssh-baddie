// go-backend/internal/api/handlers.go
package api

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"ssh-ui-backend/internal/ssh"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	sessionManager *ssh.SessionManager
}

func NewHandler(sm *ssh.SessionManager) *Handler {
	return &Handler{sessionManager: sm}
}

type ConnectRequest struct {
	Host       string `json:"host" binding:"required"`
	Port       int    `json:"port" binding:"required"`
	Username   string `json:"username" binding:"required"`
	Password   string `json:"password"`
	PrivateKey string `json:"private_key"`
	Passphrase string `json:"passphrase"`
}

type ConnectResponse struct {
	SessionID string `json:"session_id"`
}

func (h *Handler) Connect(c *gin.Context) {
	var req ConnectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	config := ssh.ConnectionConfig{
		Host:       req.Host,
		Port:       req.Port,
		Username:   req.Username,
		Password:   req.Password,
		PrivateKey: req.PrivateKey,
		Passphrase: req.Passphrase,
	}

	client, err := ssh.Connect(config)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	sftpClient, err := ssh.NewSFTPClient(client)
	if err != nil {
		client.Close()
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("SFTP init failed: %v", err)})
		return
	}

	sessionID := uuid.New().String()
	session := &ssh.Session{
		ID:         sessionID,
		Client:     client,
		SFTPClient: sftpClient,
	}

	h.sessionManager.AddSession(sessionID, session)

	c.JSON(http.StatusOK, ConnectResponse{SessionID: sessionID})
}

func (h *Handler) Disconnect(c *gin.Context) {
	sessionID := c.Param("session_id")

	if err := h.sessionManager.RemoveSession(sessionID); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "disconnected"})
}

type ExecuteCommandRequest struct {
	SessionID string `json:"session_id" binding:"required"`
	Command   string `json:"command" binding:"required"`
}

type ExecuteCommandResponse struct {
	Output string `json:"output"`
}

func (h *Handler) ExecuteCommand(c *gin.Context) {
	var req ExecuteCommandRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, err := h.sessionManager.GetSession(req.SessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	output, err := ssh.ExecuteCommand(session.Client, req.Command)
	if err != nil {
		c.JSON(http.StatusOK, ExecuteCommandResponse{Output: output})
		return
	}

	c.JSON(http.StatusOK, ExecuteCommandResponse{Output: output})
}

func (h *Handler) ListFiles(c *gin.Context) {
	sessionID := c.Query("session_id")
	path := c.Query("path")

	if sessionID == "" || path == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "session_id and path required"})
		return
	}

	session, err := h.sessionManager.GetSession(sessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	files, err := session.SFTPClient.ListFiles(path)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if files == nil {
		files = []ssh.FileInfo{}
	}

	c.JSON(http.StatusOK, gin.H{"files": files})
}

func (h *Handler) UploadFile(c *gin.Context) {
	sessionID := c.PostForm("session_id")
	remotePath := c.PostForm("remote_path")

	if sessionID == "" || remotePath == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "session_id and remote_path required"})
		return
	}

	session, err := h.sessionManager.GetSession(sessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file required"})
		return
	}

	// Save to temp file
	tempFile := filepath.Join(os.TempDir(), uuid.New().String())
	if err := c.SaveUploadedFile(file, tempFile); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer os.Remove(tempFile)

	// Upload to remote
	if err := session.SFTPClient.UploadFile(tempFile, remotePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "uploaded"})
}

func (h *Handler) DownloadFile(c *gin.Context) {
	sessionID := c.Query("session_id")
	remotePath := c.Query("remote_path")

	if sessionID == "" || remotePath == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "session_id and remote_path required"})
		return
	}

	session, err := h.sessionManager.GetSession(sessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	// Download to temp file
	tempFile := filepath.Join(os.TempDir(), uuid.New().String())
	if err := session.SFTPClient.DownloadFile(remotePath, tempFile); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer os.Remove(tempFile)

	// Stream to client
	file, err := os.Open(tempFile)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer file.Close()

	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filepath.Base(remotePath)))
	c.Header("Content-Type", "application/octet-stream")
	io.Copy(c.Writer, file)
}

func (h *Handler) DeleteFile(c *gin.Context) {
	var req struct {
		SessionID string `json:"session_id" binding:"required"`
		Path      string `json:"path" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, err := h.sessionManager.GetSession(req.SessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	if err := session.SFTPClient.DeleteFile(req.Path); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}

func (h *Handler) CreateDirectory(c *gin.Context) {
	var req struct {
		SessionID string `json:"session_id" binding:"required"`
		Path      string `json:"path" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, err := h.sessionManager.GetSession(req.SessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	if err := session.SFTPClient.CreateDirectory(req.Path); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "created"})
}

func (h *Handler) RenameFile(c *gin.Context) {
	var req struct {
		SessionID string `json:"session_id" binding:"required"`
		OldPath   string `json:"old_path" binding:"required"`
		NewPath   string `json:"new_path" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, err := h.sessionManager.GetSession(req.SessionID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	if err := session.SFTPClient.RenameFile(req.OldPath, req.NewPath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "renamed"})
}
