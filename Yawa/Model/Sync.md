Two clients have two different sets of transactions. The goal is to sync them so after the syncing process two sets are identical.

*Process*
Let's say B finds A first and sends merge request with SyncData object which includes:
* transactions: [Transaction]
* deviceID: String, unique identifier that keeps persistent between launches
* requestType: merge or update. Initially peer sets this to Merge so another peer makes merge and sends back merged results as an Update request.

Each peer for each device it ever synced with has local list of hashes of transactions that were presented after the last sync with that device: “transactionsFromLastSync[deviceID]”. This list is used to determine whether file should be deleted and kept during merge.

Each transaction has creation date and author. They in hash calculation so it keeps persistent through the time. Also transaction has modification date to decide update from which device is newer.

*Merge cases*
* A has transaction X, B hasn't
If X was in the last sync — delete it, otherwise — keep
* Both A and B has identical transaction X — keep
* Both A and B has transaction X but with different modifications
Keep newer version

*Algo*
1. B invites A and sends SyncData with requestType = Merge
2. A makes merge
1. Creates “localIndex”: index of local transactions: hash to index. 
2. Creates an array “processedTransactions” to track which transaction is already processed
3. For each transaction in B makes merge operation according to the list of cases above, adding it to (or removing it from) the A’s transactions list to use less memory
4. For each transaction in A that was not processed yet (determined with “processedTransactions” array) makes merge operation
3. Sort all transactions by date (one that could be updated by user, not creation date or last update date)
4. Updates it’s own transactionsFromLastSync[deviceID]
5. Sends new SyncData with merged transactions, requestType = Update and transactionsFromLastSync[deviceID]
6. Saves transactions and transactionsFromLastSync[deviceID] to disk

When B receives results of Merge it should:
1. Update local transactions
2. Update transactionsFromLastSync[deviceID]
3. Save it all to disk
