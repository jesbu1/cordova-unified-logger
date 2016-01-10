//
//  DBLogging.m
//  referenceSidebarApp
//
//  Created by Kalyanaraman Shankari on 1/9/16.
//
//

#import "DBLogging.h"

// Table name
#define TABLE_LOG @"logTable"

#define KEY_ID @"ID"
#define KEY_TS @"ts"
#define KEY_LEVEL @"level"
#define KEY_MESSAGE @"message"

#define DB_FILE_NAME @"loggerDB"

@interface DBLogging()

@end

@implementation DBLogging

static DBLogging *_database;

+ (DBLogging*)database {
    if (_database == nil) {
        _database = [[DBLogging alloc] init];
    }
    return _database;
}

// TODO: Refactor this into a new database helper class?
- (id)init {
    if ((self = [super init])) {
        NSString *sqLiteDb = [self dbPath:DB_FILE_NAME];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if (![fileManager fileExistsAtPath: sqLiteDb]) {
            // Copy existing database over to create a blank DB.
            // Apparently, we cannot create a new file there to work as the database?
            // http://stackoverflow.com/questions/10540728/creating-an-sqlite3-database-file-through-objective-c
            NSError *error = nil;
            NSString *readableDBPath = [[NSBundle mainBundle] pathForResource:DB_FILE_NAME
                                                                       ofType:nil];
            NSLog(@"Copying file from %@ to %@", readableDBPath, sqLiteDb);
            BOOL success = [[NSFileManager defaultManager] copyItemAtPath:readableDBPath
                                                                   toPath:sqLiteDb
                                                                    error:&error];
            if (!success)
            {
                NSCAssert1(0, @"Failed to create writable database file with message '%@'.", [  error localizedDescription]);
                return nil;
            }
        }
        // if we didn't have a file earlier, we just created it.
        // so we are guaranteed to always have a file when we get here
        assert([fileManager fileExistsAtPath: sqLiteDb]);
        int returnCode = sqlite3_open([sqLiteDb UTF8String], &_database);
        if (returnCode != SQLITE_OK) {
            NSLog(@"Failed to open database because of error code %d", returnCode);
            return nil;
        }
    }
    return self;
}

- (NSString*)dbPath:(NSString*)dbName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *documentsPath = [documentsDirectory
                               stringByAppendingPathComponent:dbName];
    
    return documentsPath;
}

- (void)dealloc {
    sqlite3_close(_database);
}

/*
 * BEGIN: database logging
 */

-(void)log:(NSString *)message atLevel:(NSString*)level {
    NSString *insertStatement = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@) VALUES (?, ?, ?)",
                                 TABLE_LOG, KEY_TS, KEY_LEVEL, KEY_MESSAGE];
    
    sqlite3_stmt *compiledStatement;
    NSInteger insertPrepCode = sqlite3_prepare_v2(_database, [insertStatement UTF8String], -1, &compiledStatement, NULL);
    if(insertPrepCode == SQLITE_OK) {
        // The SQLITE_TRANSIENT is used to indicate that the raw data (userMode, tripId, sectionId
        // is not permanent data and the SQLite library should make a copy
        sqlite3_bind_int64(compiledStatement, 1, [NSDate date].timeIntervalSince1970);
        sqlite3_bind_text(compiledStatement, 3, [level UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(compiledStatement, 2, [message UTF8String], -1, SQLITE_TRANSIENT);
        NSInteger execCode = sqlite3_step(compiledStatement);
        if (execCode != SQLITE_DONE) {
            @throw [NSException exceptionWithName:@"SQLError"
                        reason:[NSString stringWithFormat:@"Got error code %ld while executing statement %@", (long)execCode, insertStatement]
                        userInfo: nil];
        }
    } else {
        @throw [NSException exceptionWithName:@"SQLError"
                    reason:[NSString stringWithFormat:@"Got error code %ld while compiling statement %@", (long)insertPrepCode, insertStatement]
                    userInfo: nil];
    }
    // Shouldn't this be within the prior if?
    // Shouldn't we execute the compiled statement only if it was generated correctly?
    // This is code copied from
    // http://stackoverflow.com/questions/2184861/how-to-insert-data-into-a-sqlite-database-in-iphone
    // Need to check from the raw sources and see where we get
    // Create a new sqlite3 database like so:
    // http://www.raywenderlich.com/902/sqlite-tutorial-for-ios-creating-and-scripting
    sqlite3_finalize(compiledStatement);
}

-(void)clear {
    NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@", TABLE_LOG];
    sqlite3_stmt *compiledStatement;
    NSInteger delPrepCode = sqlite3_prepare_v2(_database, [deleteQuery UTF8String], -1, &compiledStatement, NULL);
    if (delPrepCode == SQLITE_OK) {
        NSInteger execCode = sqlite3_step(compiledStatement);
        if (execCode != SQLITE_DONE) {
            @throw [NSException exceptionWithName:@"SQLError"
                        reason:[NSString stringWithFormat:@"Got error code %ld while executing statement %@", (long)execCode, deleteQuery]
                        userInfo: nil];
        }
    } else {
        @throw [NSException exceptionWithName:@"SQLError"
                    reason:[NSString stringWithFormat:@"Got error code %ld while compiling statement %@", (long)delPrepCode, deleteQuery]
                    userInfo: nil];
    }
    sqlite3_finalize(compiledStatement);
}

/*
 * END: database logging
 */

@end