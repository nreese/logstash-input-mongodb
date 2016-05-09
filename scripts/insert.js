var cursor = db.items.find({});
var uniqueToken = cursor.count() + 1;
var now = new Date();
var doc = {_id: uniqueToken, lastModified: now.toISOString() + "_" + uniqueToken};
db.items.insert(doc);
print("Inserted new document: " + JSON.stringify(doc, null, 4));