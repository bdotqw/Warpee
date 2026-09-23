local addonName, ns = ...

local WORDS = {
  ["tropa"] = "warband",
}

local STRINGS = {
  ["Bank and Warband grid"] = "Cuadrícula del banco y la tropa",
  ["BoE while unbound, WuE for warbound until equipped, BoA for account bound."] = "BoE mientras no está vinculado, WuE vinculado a la tropa hasta equipar, BoA a la cuenta.",
  ["Warband slots per row"] = "Espacios por fila (tropa)",
  ["The exclamation mark on items for quests you have not picked up yet. Not shown in the warband bank."] = "El signo de exclamación en los objetos de misiones que aún no has aceptado. No se muestra en el banco de la tropa.",
  ["Include Warband"] = "Incluir la tropa",
  ["Count the shared Warband bank on its own line."] = "Cuenta el banco compartido de la tropa en una línea aparte.",
  ["Gold tooltip over the money in the window corner: every character's gold, the Warband bank, the total and the WoW Token price."] = "Información de oro sobre el dinero en la esquina de la ventana: el oro de cada personaje, el banco de la tropa, el total y el precio de la ficha.",
  ["Remember Warband bank"] = "Guardar el banco de la tropa",
  ["Save the shared Warband bank while you stand at a banker."] = "Guarda el banco compartido de la tropa mientras estás con un banquero.",
  ["Delete the saved Warband bank?"] = "¿Borrar el banco de la tropa guardado?",
  ["Keep warbound"] = "Guardar ligados a la tropa",
  ["Sell raid armor tokens, item level ignored. Only from the expansions ticked below."] = "Vende las fichas de armadura de tropa, sin tener en cuenta el nivel de objeto. Solo las de las expansiones marcadas abajo.",
  ["Skip warbound gear, since an alt can still use it."] = "Omite el equipo ligado a la tropa: otro personaje todavía puede usarlo.",
  ["Bank / Warband"] = "Banco / Tropa",
  ["WARBAND BANK"] = "BANCO DE LA TROPA",
  ["Warband"] = "Tropa",
  ["Put your gold into the Warband bank"] = "Depositar tu oro en el banco de la tropa",
  ["Take gold out of the Warband bank"] = "Sacar oro del banco de la tropa",
  ["Buy another Warband bank tab"] = "Comprar otra pestaña del banco de la tropa",
  ["Warband bank"] = "Banco de la tropa",
  ["Spanish (LatAm)"] = "Español (LatAm)",
  ["New group"] = "Nuevo grupo",
  ["Ungrouped"] = "Sin grupo",
  ["Group"] = "Grupo",
  ["Essentials"] = "Esenciales",
  ["Gear"] = "Equipo",
  ["Collections"] = "Colecciones",
    ["Each row is either a category — a search read top to bottom, where an item joins the first it matches — or a marker: a group header naming the band under it, or a divider seaming one off. Drag a row by its grip to move it, the box on the left turns a category off, and the X takes a row out; a removed group header leaves its categories where they are. The strip above adds a ready-made category, and the buttons under the list add a new row at its bottom — the view scrolls to it and it flashes."] = "Cada fila es una categoría —una búsqueda de arriba abajo, donde un objeto entra en la primera que coincide— o un marcador: un encabezado de grupo que nombra la banda que tiene debajo, o un separador que separa una banda. Arrastra una fila por su agarre para moverla, la casilla de la izquierda desactiva una categoría y la X quita una fila; un encabezado eliminado deja sus categorías donde están. La tira de arriba agrega una categoría ya hecha, y los botones bajo la lista agregan una fila nueva al final: la vista baja hasta ella y parpadea.",
  ["Divider"] = "Separador",
  ["New divider"] = "Nuevo separador",
  ["Reset the category list to the shipped one?"] = "¿Restablecer la lista de categorías a la de serie?",
  ["Adds a category at the bottom of the list, ready to drag into place"] = "Agrega una categoría al final de la lista, lista para arrastrarla a su sitio",
  ["Adds an empty group at the bottom, then drag it up to head the rows it should name"] = "Agrega un grupo vacío al final; arrástralo hacia arriba para encabezar las filas que debe nombrar",
  ["Adds a divider at the bottom, then drag it up to seam the rows where you want"] = "Agrega un separador al final; arrástralo hacia arriba para separar las filas que quieras",
  ["Asks first, then puts every shipped category back"] = "Pregunta antes y después devuelve todas las categorías de serie",
  ["Damaged code"] = "Código dañado",
  ["Before import"] = "Antes de importar",
  ["Categories code"] = "Código de categorías",
  ["Imported sections: %d"] = "Secciones importadas: %d",
  ["Replace the category list with this code?"] = "¿Reemplazar la lista de categorías con este código?",
  ["Replace list"] = "Reemplazar lista",
}

ns.AddLocale("esMX", "Spanish (LatAm)", {
  strings = STRINGS,
  words = WORDS,
})
