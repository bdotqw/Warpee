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
}

ns.AddLocale("esMX", "Spanish (LatAm)", {
  strings = STRINGS,
  words = WORDS,
})
