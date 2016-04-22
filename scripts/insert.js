var cursor = db.items.find({});
var val = cursor.count() + 1;
db.items.insert({value:val, lastModified: new Date()});