# MySQL Thread Pool Monitoring

This plugin monitors the [MySQL Thread Pool](http://dev.mysql.com/doc/refman/5.5/en/thread-pool-plugin.html) by tracking the rate-of-change of the important fields from the [`INFORMATION_SCHEMA TP_THREAD_GROUP_STATS` Table](http://dev.mysql.com/doc/refman/5.5/en/tp-thread-group-stats-table.html).
Sudden spikes indicate abnormal events (esp. regarding the `*_WAITS` fields).

Created by [Jon Bardin](https://github.com/diclophis)