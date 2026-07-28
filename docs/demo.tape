Output docs/demo.gif

Set Shell "bash"
Set FontSize 18
Set Width 1450
Set Height 700
Set Padding 20
Set Theme "Dracula"
Set TypingSpeed 20ms

Hide
Type "rm -rf /tmp/run-sh-vhs-demo && mkdir -p /tmp/run-sh-vhs-demo/home /tmp/run-sh-vhs-demo/workspace && export HOME=/tmp/run-sh-vhs-demo/home && export SHELL=/bin/bash && export PS1='$ ' && cd /tmp/run-sh-vhs-demo/workspace && clear"
Enter
Sleep 300ms
Show

# 1. Clean folder -> my-project -> curl install
Type "mkdir my-project && cd my-project"
Enter
Type "curl -fsSL https://raw.githubusercontent.com/imgproxy/run.sh/main/run -o run && chmod +x run"
Enter
Sleep 800ms
Type "ls"
Enter
Sleep 1s

Hide
Type "clear"
Enter
Sleep 200ms
Show

# 2. Run with no tasks yet
Type "./run"
Enter
Sleep 3.5s

Hide
Type "clear"
Enter
Sleep 200ms
Show

# 3. Create first example task via curl, run it, get its help
Hide
Type "mkdir -p bin && curl -fsSL https://raw.githubusercontent.com/imgproxy/run.sh/main/examples/task.sh -o bin/deploy.sh"
Enter
Sleep 200ms
Show
Type "ls ./bin"
Enter
Sleep 800ms
Type "./run"
Enter
Sleep 2s
Type "./run deploy 1.2.3 --dry-run"
Enter
Sleep 1.2s
Type "./run help deploy"
Enter
Sleep 1.5s
