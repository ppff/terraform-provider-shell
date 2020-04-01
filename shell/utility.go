package shell

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"runtime"
	"strings"

	"github.com/mitchellh/go-linereader"
	"github.com/tidwall/gjson"
)

// State is a wrapper around both the input and output attributes that are relavent for updates
type State struct {
	Environment []string
	Output      map[string]string
}

// NewState is the constructor for State
func NewState(environment []string, output map[string]string) *State {
	return &State{Environment: environment, Output: output}
}

// in case of duplicates, ev2 will overwrite ev1 entries
func mergeEnvironmentMaps(ev1 map[string]interface{}, ev2 map[string]interface{}) map[string]interface{} {
    res := ev1
    if ev2 != nil {
		for k, v := range ev2 {
			res[k] = v
		}
	}
    return res
}

func readEnvironmentVariables(ev map[string]interface{}) []string {
	var variables []string
	if ev != nil {
		for k, v := range ev {
			variables = append(variables, k+"="+v.(string))
		}
	}
	return variables
}

func printStackTrace(stack []string) {
	log.Printf("-------------------------")
	log.Printf("[DEBUG] Current stack:")
	for _, v := range stack {
		log.Printf("[DEBUG] -- %s", v)
	}
	log.Printf("-------------------------")
}

func runCommand(command string, state *State, environment []string, workingDirectory string) (*State, error) {
	shellMutexKV.Lock(shellScriptMutexKey)
	defer shellMutexKV.Unlock(shellScriptMutexKey)

	// Execute the command using a shell
	var shell, flag string
	if runtime.GOOS == "windows" {
		shell = "cmd"
		flag = "/C"
	} else {
		shell = "/bin/sh"
		flag = "-c"
	}

	// Setup the command
	cmd := exec.Command(shell, flag, command)
	input, _ := json.Marshal(state.Output)
	stdin := bytes.NewReader(input)
	cmd.Stdin = stdin
	environment = append(os.Environ(), environment...)
	cmd.Env = environment
	prStdout, pwStdout, err := os.Pipe()
	if err != nil {
		return nil, fmt.Errorf("failed to initialize pipe for stdout: %s", err)
	}
	cmd.Stdout = pwStdout
	prStderr, pwStderr, err := os.Pipe()
	if err != nil {
		return nil, fmt.Errorf("failed to initialize pipe for stderr: %s", err)
	}
	cmd.Stderr = pwStderr
	cmd.Dir = workingDirectory

	log.Printf("[DEBUG] shell script command old state: \"%v\"", state)

	// Output what we're about to run
	log.Printf("[DEBUG] shell script going to execute: %s %s", shell, flag)
	commandLines := strings.Split(command, "\n")
	for _, line := range commandLines {
		log.Printf("   %s", line)
	}

	//send sdout and stderr to reader
	logCh := make(chan string)
	stdoutDoneCh := make(chan string)
	stderrDoneCh := make(chan string)
	go readOutput(prStderr, logCh, stderrDoneCh)
	go readOutput(prStdout, logCh, stdoutDoneCh)
	go logOutput(logCh)
	// Start the command
	log.Printf("-------------------------")
	log.Printf("[DEBUG] Starting execution...")
	log.Printf("-------------------------")
	err = cmd.Start()
	if err == nil {
		err = cmd.Wait()
	}

	// Close the write-end of the pipe so that the goroutine mirroring output
	// ends properly.
	pwStdout.Close()
	pwStderr.Close()
	stdOutput := <-stdoutDoneCh
	<-stderrDoneCh
	close(logCh)

	log.Printf("-------------------------")
	log.Printf("[DEBUG] Command execution completed:")
	log.Printf("-------------------------")
	o := getOutputMap(stdOutput)
	//if output is nil then no state was returned from output
	if o == nil {
		return nil, nil
	}
	newState := NewState(environment, o)
	log.Printf("[DEBUG] shell script command new state: \"%v\"", newState)
	return newState, nil
}

func logOutput(logCh chan string) {
	for line := range logCh {
		log.Printf("  %s", line)
	}
}

func readOutput(r io.Reader, logCh chan<- string, doneCh chan<- string) {
	defer close(doneCh)
	lr := linereader.New(r)
	var output strings.Builder
	for line := range lr.Ch {
		logCh <- line
		output.WriteString(line)
	}
	doneCh <- output.String()
}

func parseJSON(s string) (map[string]string, error) {
	if !gjson.Valid(s) {
		return nil, fmt.Errorf("Invalid JSON: %s", s)
	}
	output := make(map[string]string)
	result := gjson.Parse(s)
	result.ForEach(func(key, value gjson.Result) bool {
		output[key.String()] = value.String()
		return true
	})
	return output, nil
}

func getOutputMap(s string) map[string]string {
	//Find all matches of "{(.*)/g" in output
	var matches []string
	substring := s
	idx := strings.Index(substring, "{")
	for idx != -1 {
		substring = substring[idx:]
		matches = append(matches, substring)
		if len(substring) > 0 {
			substring = substring[1:]
		}
		idx = strings.Index(substring, "{")
	}

	//Use last match that is a valid JSON
	var m map[string]string
	var err error
	for i := range matches {
		match := matches[len(matches)-1-i]
		m, err = parseJSON(match)
		if err == nil {
			//match found
			break
		}
	}

	if m == nil {
		log.Printf("[DEBUG] no valid JSON strings found at end of output: \n%s", s)
		return nil
	}

	log.Printf("[DEBUG] Valid map[string]string:\n %v", m)
	return m
}

func readFile(r io.Reader) string {
	const maxBufSize = 8 * 1024
	buffer := new(bytes.Buffer)
	for {
		tmpdata := make([]byte, maxBufSize)
		bytecount, _ := r.Read(tmpdata)
		if bytecount == 0 {
			break
		}
		buffer.Write(tmpdata)
	}
	return buffer.String()
}
