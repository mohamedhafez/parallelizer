package org.rubygems.parallelizer;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

// compare this class to defaultDaemonThreadFactory, whose source you can see at
// https://github.com/AdoptOpenJDK/openjdk-jdk11u/blob/5f01925b80ed851b133ee26fbcb07026ac04149e/src/java.base/share/classes/java/util/concurrent/Executors.java#L612-L637
// the only changes are lines 27-28: making the thread a deamon thread
public class DefaultDaemonThreadFactory implements ThreadFactory {
	static final AtomicInteger poolNumber = new AtomicInteger(1);
	final ThreadGroup group;
	final AtomicInteger threadNumber = new AtomicInteger(1);
	final String namePrefix;

	public DefaultDaemonThreadFactory() {
		SecurityManager s = System.getSecurityManager();
		group = (s != null)? s.getThreadGroup() :
			Thread.currentThread().getThreadGroup();
		namePrefix = "pool-" +
				poolNumber.getAndIncrement() +
				"-thread-";
	}

	public Thread newThread(Runnable r) {
		Thread t = new Thread(group, r,
				namePrefix + threadNumber.getAndIncrement(),
				0);
		if (!t.isDaemon())
			t.setDaemon(true);
		if (t.getPriority() != Thread.NORM_PRIORITY)
			t.setPriority(Thread.NORM_PRIORITY);
		return t;
	}
}
