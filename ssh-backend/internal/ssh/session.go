// go-backend/internal/ssh/session.go
package ssh

import (
	"fmt"
	"sync"

	"golang.org/x/crypto/ssh"
)

type Session struct {
	ID         string
	Client     *ssh.Client
	SFTPClient *SFTPClient
}

type SessionManager struct {
	sessions map[string]*Session
	mu       sync.RWMutex
}

func NewSessionManager() *SessionManager {
	return &SessionManager{
		sessions: make(map[string]*Session),
	}
}

func (sm *SessionManager) AddSession(id string, session *Session) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.sessions[id] = session
}

func (sm *SessionManager) GetSession(id string) (*Session, error) {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	session, exists := sm.sessions[id]
	if !exists {
		return nil, fmt.Errorf("session not found")
	}
	return session, nil
}

func (sm *SessionManager) RemoveSession(id string) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, exists := sm.sessions[id]
	if !exists {
		return fmt.Errorf("session not found")
	}

	if session.SFTPClient != nil {
		session.SFTPClient.Close()
	}
	if session.Client != nil {
		session.Client.Close()
	}

	delete(sm.sessions, id)
	return nil
}
