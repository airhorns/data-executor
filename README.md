# Data Executor

`dexec` is a simple unix process for executing other processes and collecting information about them. `dexec` executes one command and reports things like the start time, end time, and exit status code to a HTTP server.

This is useful to unify the monitoring of heterogeneous work loads across systems. If a team has many different tools that all run using different technology stacks, different scheduling schemes, on different servers, it can get tough to monitor them all. A collector built on top of the data `dexec` spits out can render out a uniform list of all the stuff being done and the run history of all of it. Asking simple questions like "is the run time of this particular job growing week over week" or "how often does this cron job fail" becomes easy to ask of any job in the system if `dexec` is liberally applied.

`dexec` is built such that it can just sit between something like cron and an existing workload scheduled by it:

```crontab
0 0,12 1 */2 * /sbin/ping -c 192.168.0.1; ls -la >>/var/log/cronrun
```

can just become

```crontab
0 0,12 1 */2 * dexec --collector=http://watchmen:7789/ --namespace=cron-pings -- /sbin/ping -c 192.168.0.1; ls -la >>/var/log/cronrun
```

and data will start getting sent.

### Example:

`bin/dexec exit 0` will make two POST requests with JSON bodies to an HTTP server collector at localhost:7789. The first would arrive right after the command was started, and look like:

```json
{
    ":command": "foo --trace",
    ":jid": "2395ad2f5fa743d575d60328ce6edf76",
    ":name": "dexec-anon-2395ad2f5fa743d575d60328ce6edf76",
    ":state": ":started",
    ":time": {
        "^t": 1393109734.172588
    },
    ":user": "hornairs",
    ":host":"oration.local"
}
```

and the second would arrive after the command had finished and look like:

```json
{
    ":exit_code": 1,
    ":jid": "2395ad2f5fa743d575d60328ce6edf76",
    ":name": "dexec-anon-2395ad2f5fa743d575d60328ce6edf76",
    ":state": ":finished",
    ":time": {
        "^t": 1393109734.175794
    }
}
```

The weird json shape for the keys and `time` field there is from the `oj` gem which gives itself little hints for what something should be on the other side during deserialization.


### Architecture

`dexec` is a really thin wrapper around the [God](http://godrb.com/). God is purpose built to be wildly stable, so `dexec` is too. Its a simple unix utility that forks and execs your passed in process without really much in between at all.

`dexec` sends data out over HTTP, cause everything in the world speaks it.

`dexec` is written in Ruby cause its plenty fast for this, God already existed, and its very easy to change. Though it would be nice to not have gem dependencies or require a ruby run time, so a go-lang rewrite might be prudent in the future.

`dexec` doesn't have a UI because small loosely coupled components are easier to iterate on, and it doesn't make sense to have the UI code/dependencies everywhere that is just doing work.

`dexec` logs to STDERR and the passes along anything logged by the execution of the command along to `dexec`'s STDIN and STDERR.

# Future plans

`dexec` can implement a bunch of different stuff in the future:

 - locking around jobs in zookeeper to prevent trampling
 - automatic logging of cpu and memory usage to StatsD or Datadog
 - cpu and memory limits and warnings
 - timeouts
 - interfacing with the inner process to get out rich monitoring information
 - interfacing with the inner process to understand dependency stuff and report that to a collector for UI purposes
