// go-backend/main.go
package main

import (
	"flag"
	"fmt"
	"log"
	"ssh-ui-backend/internal/api"
	"ssh-ui-backend/internal/ssh"

	"github.com/gin-gonic/gin"
)

func main() {
	port := flag.Int("port", 8822, "Port to run the server on")
	flag.Parse()

	// Initialize session manager
	sessionManager := ssh.NewSessionManager()

	// Setup Gin router
	gin.SetMode(gin.ReleaseMode)
	router := gin.Default()

	// CORS middleware
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// API routes
	apiHandler := api.NewHandler(sessionManager)

	// SSH routes
	router.POST("/api/ssh/connect", apiHandler.Connect)
	router.DELETE("/api/ssh/session/:session_id", apiHandler.Disconnect)
	router.POST("/api/ssh/exec", apiHandler.ExecuteCommand)

	// WebSocket terminal
	router.GET("/api/terminal/:session_id", apiHandler.TerminalWebSocket)

	router.GET("/api/sftp/list", apiHandler.ListFiles)
	router.POST("/api/sftp/upload", apiHandler.UploadFile)
	router.GET("/api/sftp/download", apiHandler.DownloadFile)
	router.DELETE("/api/sftp/delete", apiHandler.DeleteFile)
	router.POST("/api/sftp/mkdir", apiHandler.CreateDirectory)
	router.POST("/api/sftp/rename", apiHandler.RenameFile)

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("SSH Backend starting on %s", addr)
	if err := router.Run(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
