// go-backend/internal/ssh/sftp.go
package ssh

import (
	"fmt"
	"io"
	"os"
	"time"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

type SFTPClient struct {
	client *sftp.Client
}

type FileInfo struct {
	Name         string    `json:"name"`
	Path         string    `json:"path"`
	IsDirectory  bool      `json:"is_directory"`
	Size         int64     `json:"size"`
	ModifiedTime time.Time `json:"modified_time"`
	Permissions  string    `json:"permissions"`
}

func NewSFTPClient(sshClient *ssh.Client) (*SFTPClient, error) {
	client, err := sftp.NewClient(sshClient)
	if err != nil {
		return nil, fmt.Errorf("failed to create SFTP client: %v", err)
	}

	return &SFTPClient{client: client}, nil
}

func (sc *SFTPClient) Close() error {
	return sc.client.Close()
}

func (sc *SFTPClient) ListFiles(path string) ([]FileInfo, error) {
	files, err := sc.client.ReadDir(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read directory: %v", err)
	}

	var fileInfos []FileInfo
	for _, file := range files {
		fullPath := path
		if path != "/" {
			fullPath = path + "/" + file.Name()
		} else {
			fullPath = "/" + file.Name()
		}

		fileInfos = append(fileInfos, FileInfo{
			Name:         file.Name(),
			Path:         fullPath,
			IsDirectory:  file.IsDir(),
			Size:         file.Size(),
			ModifiedTime: file.ModTime(),
			Permissions:  file.Mode().String(),
		})
	}

	return fileInfos, nil
}

func (sc *SFTPClient) UploadFile(localPath, remotePath string) error {
	srcFile, err := os.Open(localPath)
	if err != nil {
		return fmt.Errorf("failed to open local file: %v", err)
	}
	defer srcFile.Close()

	dstFile, err := sc.client.Create(remotePath)
	if err != nil {
		return fmt.Errorf("failed to create remote file: %v", err)
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return fmt.Errorf("failed to copy file: %v", err)
	}

	return nil
}

func (sc *SFTPClient) DownloadFile(remotePath, localPath string) error {
	srcFile, err := sc.client.Open(remotePath)
	if err != nil {
		return fmt.Errorf("failed to open remote file: %v", err)
	}
	defer srcFile.Close()

	dstFile, err := os.Create(localPath)
	if err != nil {
		return fmt.Errorf("failed to create local file: %v", err)
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return fmt.Errorf("failed to copy file: %v", err)
	}

	return nil
}

func (sc *SFTPClient) DeleteFile(path string) error {
	return sc.client.Remove(path)
}

func (sc *SFTPClient) CreateDirectory(path string) error {
	return sc.client.Mkdir(path)
}

func (sc *SFTPClient) RenameFile(oldPath, newPath string) error {
	return sc.client.Rename(oldPath, newPath)
}
