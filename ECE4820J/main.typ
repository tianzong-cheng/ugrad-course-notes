#import "@preview/ilm:1.2.1": *

#set text(lang: "en")

#show: ilm.with(
  title: [Notes for ECE4820J],
  author: "Tianzong Cheng",
  figure-index: (enabled: true),
  table-index: (enabled: true),
  listing-index: (enabled: true)
)

= Operating Systems Overview

== Computers and Operating Systems

- Job of an Operating System (OS):
  - Manage and assign the hardware resources
  - Hide complicated details to the end user
  - Provide abstractions to ease interactions with the hardware

== Hardware

- CMOS: save time and date, BIOS parameters
  - powered by the CMOS battery

== Basic concepts

- Five major components of an OS:
  - System calls: allows to interface with user-space
  - Processes: defines everything needed to run programs
  - File system: store persistent data
  - Input-Output (IO): allows to interface with hardware
  - Protection and Security: keep the system safe
- Monolithic kernel, micro kernel
  - Monolithic kernel
    - Everything in kernel space
    - Pros
      - High performance: communication between kernel components avoid overhead
    - Cons
      - Changes or bugs can affect the whole kernel
  - Micro kernel
    - Minimal kernel space
    - Pros
      - Higher stabability
    - Cons
      - Performance overhead

= Processes and Threads

== Processes

- *Process is the unit for resource management*
- Multiprogramming issue: rate of computation of a process is not uniform / reproducible
- Process hierarchies
  - UNIX
    - parent-child
    - "process group"
  - Windows
    - All processes are equal
    - A parent has a token to control its child
    - A token can be given to another process
- A simple model for processes:
  - A process is a data structure called process control block
  - The structure contains important information such as:
    - State
      - ready (input available)
      - running (picked by scheduler)
      - blocked (waiting for input)
    - Program counter
    - Stack pointer
    - Memory allocation
    - Open files
    - Scheduling information
  - All the processes are stored in an array called process table
- Upon an interrupt the running process must be paused:
  1. Push on the stack the user program counter, PSW (program status word), etc.
  2. Load information from interrupt vector
  3. Save registers (assembly)
  4. Setup new stack (assembly)
  5. Finish up the work for the interrupt
  6. Decides which process to run next
  7. Load the new process, i.e. memory map, registers, etc. (assembly)
- Difference between concurrency and parallelism
  - concurreny: multitasking on a single-core machine
  - parallelism: multicore processor

== Threads

- *A thread is the basic unit of CPU utilisation*
- Each thread has its own
  - thred ID
  - program counter
  - *registers*
  - *stack*
- Threads within a process share
  - code
  - data
  - OS resources
- In C or C++, if one thread crashes, it can cause the whole thread to crash.
  - For example, if one thread crashes due to invalid memory access, it can corrupt the data in the shared memory, causing other threads to crash.

== Implementation

- POSIX threads (pthread)
  - ```c int pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine) (void *), void *arg)```
  - ```c void pthread_exit(void *retval)```
  - ```c int pthread_join(pthread_t thread, void **retval)```
  - Release CPU to let another thread run: ```c int pthread_yield(void)```
  - ```c int pthread_attr_init(pthread_attr_t *attr)```
  - ```c int pthread_attr_destroy(pthread_attr_t *attr)```
- Threading models
  - Threads in user space - N:1
    - Multiple user-level threads are mapped to a single kenel thread
    - Scheduling and management are handled at the user level
    - Pros
      - Fast because context switching in kernel level is reduced
    - Cons
      - If one thread is blocked, the entire process is blocked
      - Time slices are allocated to processes, not threads. So each thread gets a smaller time slice.
  - Threads in kernel space - 1:1
    - Each user-level thread is mappend to a separate kernel thread
    - Improves responsiveness and parallelism
    - Pros
      - Blocking one thread does not affect other threads
      - Processes with several threads get more CPU time
    - Cons
      - Bigger system cost
  - Hybrid threads - M:N
    - A threading library schedules user threads on available kernel threads
    - Pros
      - Combine the strengths of user-space threads and kenel-space threads
    - Cons
      - Complexity of implementation
  - Remarks
    - Hybrid threads are less common in modern OSes

= Interprocess Communication

== Exhibiting the problem

*Race conditions*

Problems often occur when one thread does a "check-then-act":

```c
if (x == 5) {  // The "Check"
  // x is modified in another thread
  y = x * 2;  // The "Act"
}
```

A typical solution is:

```c
// Obtain lock for x
if (x == 5) {
  y = x * 2;
}
// Release lock for x
```

== Solving the Problem

*Critical region*: Part of the program where shared memory is accessed:
- No two processes can be in a critical region at a same time
- No assumption on the speed or number of CPUs
- No process outside a critical region can block other processes
- No process waits forever to enter a critical region

The lock should be obtained before checking and modifying the resource.

=== Peterson's Algorithm

Peterson's algorithm is symmetric for two processes.

```c
#define TRUE 1
#define FALSE 0
int turn;
int interested[2];
void enter_region(int p) {
  int other;
  other = 1 - p;
  interested[p] = TRUE;
  turn = p;
  while (turn == p && interested[other] == TRUE)
}
void leave_region(int p) {
  interested[p] = FALSE;
}
```

=== Mutual Exclusion at Hardware Level

- Disabling interrupts
- Use atomic operations
  - Test and set lock `TSL`

=== Semaphore

A semaphore is a positive integer and is only managed by two actions:

```c
sem.down() {
  while(sem==0) sleep();
  sem--;
}
```

```c
sem.up() {
  sem++;
}
```

An awaken sleeping process can complete its `down`.

Checking or changing the value and sleeping are done atomically:
- Single CPU: disable interrupts
- Multiple CPUs: use `TSL` to ensure only one CPU accesses the semaphore

A mutex is a semaphore taking values 0 (unlocked) or 1 (locked).

On the request of locking a mutex, if the mutex is already locked, put the calling thread to sleep.

The implementation of a mutex using `TSL`:

```
mutex-lock:
  TSL REGISTER, MUTEX
  CMP REGISTER, #0
  JZ ok
  CALL thread_yield
  JMP mutex-lock
ok:
  RET
mutex-unlock:
  MOVE MUTEX, #0
  RET
```

Using a mutex to solve the producer-consumer problem:

```c
pthread_mutex_t m;
pthread_cond_t cc, cp;
int buf = 0;

void *prod() {
  for (int i = 1; i < MAX; i++) {
    pthread_mutex_lock(&m);
    while (buf != 0)
      pthread_cond_wait(&cp, &m);
    buf = 1;
    pthread_cond_signal(&cc);
    pthread_mutex_unlock(&m);
  }
  pthread_exit(0);
}

void *cons() {
  for (int i = 1; i < MAX; i++) {
    pthread_mutex_lock(&m);
    while (buf == 0)
      pthread_cond_wait(&cc, &m);
    buf = 0;
    pthread_cond_signal(&cp);
    pthread_mutex_unlock(&m);
  }
  pthread_exit(0);
}
```

== More Solutions

=== Monitors

Basic idea behind monitors:
- The mutual exclusion is not handled by the programmer
- Locking occurs automatically
- Only one process can be active within a monitor at a time
- A monitor can be seen as a “special type of class”
- Processes can be blocked and awaken *based on condition variables and wait and signal functions*

Monitors are useful when several processes must complete before the next phase.

= Scheduling

== Requirements

- When to decide what process to run next
  - A new process is created
  - A process exits or blocks
  - IO interrupt from a device that has completed its task
- Compute bound v.s. input-output bound
- Two main strategies
  - Preemptive
    - Aprocessisrunforatmostnms
    - If it is not completed by the end of the period then it is suspended
  - Non-preemptive
    - A process runs until it blocks or voluntarily releases the CPU
    - It is resumed after an interrupt unless another process with higher priority is in the queue
- Goals when scheduling
  - All systems
    - Fairness: fair share of the CPU for each process
    - Balance: all parts of the system are busy
    - Policy enforcement: follow the defined policy
  - Interactive systems
    - Response time: quickly process requests
    - Proportionality: meet user's expectations
  - Batch systems
    - Throughput: maximise the number of jobs per hour
    - Turnaround time: minimise the time between submission and termination of a job
    - CPU utilisation: keep the CPU as busy as possible
  - Real-time systems
    - Meet deadlines: avoid any data loss
    - Predictability: avoid quality degradation, e.g. for multimedia

== Common Scheduling Algorithms

- Simplest algorithm but non-preemptive:
  - CPU is assigned in the order it is requested
  - Processes are not interrupted, they can run a long as they want
  - New jobs are put at the end of the queue
  - When a process blocks the next in line is run
  - Any blocked process becoming ready is pushed to the queue
- Shortest job first (SJF)
  - non-preemtive
  - Minimizes turnaround time
- Round-Robin scheduling
  - preemtive
  - A process runs until
    - Getting blocked
    - Its quantum has elapsed
    - Being completed
- Priority scheduling
  - Processes are more or less important, e.g. printing
  - Creates priority classes
  - Use Round-Robin within a class
  - Run higher priority processes first
- Lottery scheduling
  - preemtive
  - Processes get lottery tickets
  - When a scheduling decision is made a random ticket is chosen
  - Prize for the winner is to access resources
  - High priority processes get more tickets
- Eariliest deadline first
  - preemtive
  - Process needs to announce (i) its presence and (ii) its deadline
  - Scheduler orders processes with respect to their deadline
  - First process in the list (earliest deadline) is run

== Notes and Problems

- Limitations of the previous algorithms
  - They all assume that processes are competing
  - Parent could know which of its children is most important

Threads in user space is not able to run in the order of `A1 B1 A2 B2 A3 B3` (`A1 A2 A3` are threads of process `A`). Note that the kernel is not aware of the status of the threads in this case.

=== Dining Philosophers Problem

What is the purpose of the semaphore?

= Deadlocks

- Preemptable and non-preemptable
  - preemptable: resource can be taken away from a process without causing any negative impact
- Strategies to recover from a deadlock
  - Preemption
    - Take a resource from another process
  - Killing
    - Pick a process that can be re-run from the beginning
  - Rollback
    - Set periodical checkpoints on processes
    - Restart process at a checkpoint from before the deadlock
- States
  - Safe state: there exists an order allowing all processes to complete, even if they request their maximum number of resources when sched- uled. It can guarantee that all processes can finish.
  - Unsafe state: the ability of the system not to deadlock depends on the order the resources are allocated and deallocated. There is no way to predict whether or not all the processes will finish.
  - An unsafe state does not necessarily imply a deadlock; the system can still run for a while, or even complete all processes if some release their resources before requesting some more.
- *Conditions*
  - Mutual exclusion
    - Use daemon that can handle specific output, e.g. SPOOL
    - Aside from carefully assigning resources not much can be done
  - Hold and wait
    - Require processes to claim all the resources at once
    - Not realistic, not optimal
    - Alternative strategy: process has to release its resources before getting new ones
  - No preemption: resources cannot be taken away by another process
    - Issue inherent to the hardware
    - Often impossible to do anything
  - *Circular wait*
    - Order the resources
    - Processes have to request resources in increasing order
    - A process can only request a lower resource if it has released all the larger ones
    - *Best solution* but not always possible

= Labs

== Lab 1

- `grep -rl` prints the filenames with a match, while `grep -r` also prints the line with the match.
- Use regular expression with `grep -E`.
- `find /etc -type f -name '*netw*'`
- File descriptors
  - 0: Standard input
  - 1: Standard output
  - 2: Standard error
- `>&1` redirects the output to standard output. `2>&1 >` first redirects standard error to standard output and then redirects to a file.
- `$`
  - `$0` is the name of the script.
  - `$1` is the first argument passed to the shell. 
  - `$?` is the exit status of the last executed command. For example, 0 is success.
  - `$!` holds the process ID of the last background command.

== Lab 2

== Lab 3

- Regular Expression
  - `abc…`	Letters
  - `123…`	Digits
  - `\d`	Any Digit
  - `\D`	Any Non-digit character
  - `.`	Any Character
  - `\.`	Period
  - `[abc]`	Only a, b, or c
  - `[^abc]`	Not a, b, nor c
  - `[a-z]`	Characters a to z
  - `[0-9]`	Numbers 0 to 9
  - `\w`	Any Alphanumeric character
  - `\W`	Any Non-alphanumeric character
  - `{m}`	m Repetitions
  - `{m,n}`	m to n Repetitions
  - `*`	Zero or more repetitions
  - `+`	One or more repetitions
  - `?`	Optional character
  - `\s`	Any Whitespace
  - `\S`	Any Non-whitespace character
  - `^…$`	Starts and ends
  - `(…)`	Capture Group
  - `(a(bc))`	Capture Sub-group
  - `(.*)`	Capture all
  - `(abc|def)`	Matches abc or def

== Lab 4

- ```bash gcc -g -o sum sum.c```
- ```bash gdb --args ./sum 1 2```
- `step` `s` can debug inside a function call
- `next` `n` skips over function calls without diving into their details
- `tui enable`
- `print` `p`
- `break` `b`

== Lab 5

- Stages of compilation
  1. Pre-processing
  2. Compilation
  3. Assembly
  4. Linking
- Static libraries
  - ```bash gcc -c list.c -o list.o```
    - `-c` to compile and assemble, but do not link
  - ```bash ar rcs list.a list.o```: create an archive from the object
  - ```bash gcc -o ex2_cli ex2_cli.c -L. -l:list.a -l:middleware.a```
    - `-L.`: Adds the current directory to the list of directories where GCC will look for libraries
    - `-l:`: Specify the exact name of the library file
- Dynamic libraries
  - ```bash gcc -c *.c -fpic```
    - `-fpic`: Generates position-independent code (PIC).
  - ```bash gcc -shared list.o -o list.so```
  - ```bash gcc -o ex2_cli ex2_cli.o list.so middleware.so```
  - ```bash set -x LD_LIBRARY_PATH ./ $LD_LIBRARY_PATH```: appends the current directory

== Lab 6

== Lab 7

= Homework

== Homework 1

- Booting
  1. The computer first runs a power-on self test which ensures the basic functions of the computer is running correctly.
  2. BIOS looks for a bootable device.
  3. BIOS hands over the booting process to the found bootloader.
  4. Bootloader loads the system kernel into memory.