package main

import (
	"fmt"
	"syscall"
	"time"
)

func main() {
	for {
		fmt.Printf("UID: %d | GID: %d\n",
			syscall.Getuid(),
			syscall.Getgid(),
		)
		time.Sleep(5 * time.Second)
	}
}
