Parallelizer
============

Run commands in parallel in JRuby, on a reusable thread pool

-----

A ton of libraries already do this; what makes this one different?

1) Instead of creating and tearing down threads for every set of parallel operations, a persistent thread pool is reused.

2) Utilizes the calling thread to run one of the tasks, in order to help in keeping the required thread pool size to a minimum.

3) Does not automatically raise exceptions; instead the exception of any task is saved and returned to you along with the valid results of other tasks. This will allow your code to deal with partially successful results if it so chooses.

4) Allows you to pass a proc that will be executed if a scheduled task takes over a configurable amount of time to be assigned to a thread, so you can monitor if you need to increase the thread pool size.

##Initializing

First, you'll need to initialize a Parallelizer object, which will encapsulate your thread pool. Optional arguments are:
- `:core_pool_threads`: minimum number of threads in the pool (default 10)
- `:max_pool_threads`: max threads in the pool (default 10)
- `:keep_alive_time`: if there are more than the min # of threads, time in seconds to keep them around if they are idle (default 60)
- `:max_acceptable_delay`: if a task took longer than this number of seconds to be scheduled, run `:delayed_too_long_proc` (can be a float, defaults to nil)
- `:delayed_too_long_proc`: A proc that takes the delay in seconds as an argument, to be run if the task took more longer than `:max_acceptable_delay` to get run in the pool (defaults to nil)
- `:prestart_all_core_threads`: Normally, even if you have less than the minimum number of threads, new threads are only created and added to the pool as they are needed. If this option is set to `true` then the min number of threads will be started up immediately.

```ruby
require 'parallelizer'
p = Parallelizer.new core_pool_threads: 20, max_pool_threads: 30, max_acceptable_delay: 0.75, 
    delayed_too_long_proc: Proc.new {|delay|  puts delay }
```

##Use

Parallelizer#run takes an array of procs to run, and gives you back an equally sized array with the results of each proc, or the exception raised by it. (The last item in the array will be the one run in the calling thread. If you only have one item in the array, the thread pool won't be used at all)

```ruby
p.run [Proc.new { 2 - 1 }, Proc.new { raise "hello!" }, Proc.new { 1 + 2 }]
 =>  [1, <RuntimeError: hello!>, 3]
```

As a convenience, a `map` method is also available, that takes any Enumerable, and passes each object in it to supplied block, to be mapped to an array. The only difference between this and the regular Enumerable#map is that any mappings that raise an exception will have the exception mapped to that location. (The last item in the enumerable will be the one run in the calling thread. If you only have one item in the enumerable, the thread pool won't be used at all)

```ruby
p.map([2,4,0]) {|i| 12 / i }
 => [6, 3, <ZeroDivisionError: divided by 0>]
```

##Shutting down

The threads will be torn down during garbage collection for you so the following methods aren't usually necessary, however you can call `shutdown` to start shutting down the thread pool. From that point on any task submitted for execution on the pool will have a `Parallelizer::RejectedExecutionError` as its result (though if only a single task is to be run, it will get run on the calling thread, as it would normally, and will not return this exception). Currently queued up & running tasks will be allowed to run until completion however, and if you want to wait for those to finish you can call the `await_termination(seconds)` method, which takes a integer timeout in seconds, and will return `true` if all tasks completed and `false` if the timeout happened first.


Also, an instance of Parallelizer is, of course, threadsafe. Feel free to have just one global/class instance that you use from many different threads.

##Installation
```ruby
gem 'parallelizer'
```

##MRI & Rubinius?
I'm using ThreadPoolExecutor from Java, if someone can find/make a replication in pure Ruby it'd be pretty easy to make this also work on MRI & Rubinius
