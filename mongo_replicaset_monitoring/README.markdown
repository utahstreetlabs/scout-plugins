Forked from and uses code from the MongoDB Overview Plugin by [John Nunemaker](http://railstips.org/blog/archives/2010/07/13/mongo-scout-plugins/).

Created by [Kyle Banker](https://github.com/banker) and [Mark Weiss](https://github.com/marksweiss)

Provides overview stats of a MongoDB replica set and its individual nodes.

If a node isn't a member of a replica set, an error is generated. It's recommended to set alerts in production for 'replication_lag' >= 300 and for 'member_healthy' <= 0.
