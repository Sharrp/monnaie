# Scale adoptions
scaleFactor = Screen.width/list.width
list.scale = scaleFactor
list.center()
card.originX = 0
card.scale = scaleFactor


cardCollapsedHeight = 92
cardBottomInset = 33
cardCollapsedY = Screen.height - cardCollapsedHeight
cardExpandedY = Screen.height - card.height + cardBottomInset

animationOptions = 
	duration: 0.3
	curve: "spring(200,20,10)"

card.point = { x: 0, y: cardCollapsedY }
card.draggable.enabled = true

list.states.add
	covered:
		blur: 5

# States  
card.states.add
    expanded:
        y: cardExpandedY
card.states.animationOptions = animationOptions
list.states.animationOptions = animationOptions

# Events
card.on Events.Move, ->
	card.x = 0

card.on Events.DragEnd, ->
	velocity = card.draggable.calculateVelocity()
	if velocity.y <= 0 
		cardState = 'expanded'
		listState = 'covered'
	else
		cardState = 'default'
		listState = 'default'
	card.animate(cardState)
	list.animate(listState)

card.on Events.Tap, ->
	card.stateCycle('expanded', 'default')
	list.stateCycle('covered', 'default')

# Categories
categoriesScroll = new ScrollComponent
	size: scrollPlaceholder.size
	point: scrollPlaceholder.point
	parent: card
# 	backgroundColor: 'red'
	scrollVertical: false
scrollPlaceholder.destroy()

categoriesTitles = ['Grocery', 'Cafe', 'Transport', 'Fun', 'Bills', 'Other']
for categoryTitle, i in categoriesTitles
	newCategory = category.copy()
	newCategory.y = 0
	newCategory.x = newCategory.width * i
	newCategory.parent = categoriesScroll.content
	newCategory.children[0].text = categoryTitle
category.destroy()

# Resolve scroll conflicts
categoriesScroll.on Events.ScrollStart, ->
	card.draggable.enabled = false
	
categoriesScroll.on Events.ScrollEnd, ->
	card.draggable.enabled = true
	
card.onDragStart ->
	categoriesScroll.scrollHorizontal = false
	
card.onDragEnd ->
	categoriesScroll.scrollHorizontal = true
	
# 	categoriesScroll.enabled = false

# card.stateCycle('expanded', 'default')
# list.stateCycle('covered', 'default')