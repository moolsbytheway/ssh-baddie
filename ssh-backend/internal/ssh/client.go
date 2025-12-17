// go-backend/internal/ssh/client.go
package ssh

import (
	"fmt"
	"time"

	"golang.org/x/crypto/ssh"
)

type ConnectionConfig struct {
	Host       string
	Port       int
	Username   string
	Password   string
	PrivateKey string
	Passphrase string
}

func Connect(config ConnectionConfig) (*ssh.Client, error) {
	var authMethods []ssh.AuthMethod

	if config.PrivateKey != "" {
		var signer ssh.Signer
		var err error

		if config.Passphrase != "" {
			signer, err = ssh.ParsePrivateKeyWithPassphrase(
				[]byte(config.PrivateKey),
				[]byte(config.Passphrase),
			)
		} else {
			signer, err = ssh.ParsePrivateKey([]byte(config.PrivateKey))
		}

		if err != nil {
			return nil, fmt.Errorf("failed to parse private key: %v", err)
		}
		authMethods = append(authMethods, ssh.PublicKeys(signer))
	}

	if config.Password != "" {
		authMethods = append(authMethods, ssh.Password(config.Password))
	}

	clientConfig := &ssh.ClientConfig{
		User:            config.Username,
		Auth:            authMethods,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), // TODO: Implement proper host key verification
		Timeout:         10 * time.Second,
	}

	addr := fmt.Sprintf("%s:%d", config.Host, config.Port)
	client, err := ssh.Dial("tcp", addr, clientConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to connect: %v", err)
	}

	return client, nil
}

func ExecuteCommand(client *ssh.Client, command string) (string, error) {
	session, err := client.NewSession()
	if err != nil {
		return "", fmt.Errorf("failed to create session: %v", err)
	}
	defer session.Close()

	output, err := session.CombinedOutput(command)
	if err != nil {
		return string(output), fmt.Errorf("command failed: %v", err)
	}

	return string(output), nil
}
