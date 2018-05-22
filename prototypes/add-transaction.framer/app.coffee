cardCollapsedHeight = 92
cardBottomInset = 33
cardCollapsedY = Screen.height - cardCollapsedHeight
cardExpandedY = Screen.height - card.height + cardBottomInset

animationOptions = 
	duration: 0.3
	curve: "spring(200,20,10)"

list.point = { x: 0, y: 0 }
card.point = { x: 0, y: cardCollapsedY }

card.draggable.enabled = true

list.states.add
	covered:
		blur: 3

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
	backgroundColor: 'red'
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

card.stateCycle('expanded', 'default')
list.stateCycle('covered', 'default')