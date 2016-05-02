var cursor = db.items.find({});
var val = cursor.count() + 1;
var doc = {value:val, lastModified: new Date()};
db.items.insert(doc);
print("Inserted new document: " + JSON.stringify(doc, null, 4));