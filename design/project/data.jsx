// bgbgone — sample files for the demo

const SAMPLE_FILES = [
  { id: "f1",  name: "anna-portrait.heic",       kind: "portrait",          palette: ["#f3c4a9", "#d8a07a"], bg: "linear-gradient(160deg, #8aa9c5, #c7d6e4)", w: 2400, h: 3000, bytes: 4_120_000, modified: "Today, 09:14", state: "done",       ms: 86 },
  { id: "f2",  name: "red-sneaker-LH.jpg",       kind: "product-shoe",      palette: ["#d63b3b", "#7a1f1f"], bg: "linear-gradient(180deg, #e8e2d5, #c6bda9)", w: 4032, h: 3024, bytes: 2_240_000, modified: "Today, 09:11", state: "done",       ms: 71 },
  { id: "f3",  name: "ceramic-mug-walnut.jpg",   kind: "product-mug",       palette: ["#e7e2da", "#a08a76"], bg: "linear-gradient(160deg, #2a2a2e, #444452)", w: 3000, h: 3000, bytes: 1_810_000, modified: "Today, 09:08", state: "queued" },
  { id: "f4",  name: "tomato-vine.heic",         kind: "product-tomato",    palette: ["#d83b2c", "#5a8a3a"], bg: "linear-gradient(180deg, #f5e7c4, #d9bf85)", w: 2400, h: 2400, bytes: 1_120_000, modified: "Today, 09:02", state: "done",       ms: 64 },
  { id: "f5",  name: "team-portrait-q2.jpg",     kind: "group",             palette: ["#d8b39a", "#b48a6f", "#e7c9b1"], bg: "linear-gradient(180deg, #adb8c5, #7e8da0)", w: 5472, h: 3648, bytes: 5_900_000, modified: "Yesterday", state: "done",   ms: 104 },
  { id: "f6",  name: "vintage-typewriter.tif",   kind: "product-typewriter",palette: ["#1d1d1d", "#8a8780"], bg: "linear-gradient(180deg, #c9b58a, #8c764c)", w: 3200, h: 2400, bytes: 8_300_000, modified: "Yesterday", state: "done",       ms: 92 },
  { id: "f7",  name: "mars-rover-selfie.jpg",    kind: "product-rover",     palette: ["#c5b89c", "#5a4a36"], bg: "linear-gradient(180deg, #b46a3a, #6f3a1f)", w: 3600, h: 2700, bytes: 3_400_000, modified: "Mon · May 18", state: "error" },
  { id: "f8",  name: "mona-lisa-restored.jpg",   kind: "portrait-painting", palette: ["#e6c9a3", "#a98257"], bg: "linear-gradient(180deg, #3a3326, #20180f)", w: 2400, h: 3600, bytes: 2_800_000, modified: "Mon · May 18", state: "done", ms: 81 },
  { id: "f9",  name: "lemons-still-life.heic",   kind: "product-lemons",    palette: ["#f0c83a", "#a08418"], bg: "linear-gradient(180deg, #5c6d4e, #34402c)", w: 3000, h: 2000, bytes: 2_100_000, modified: "Mon · May 18", state: "raw" },
  { id: "f10", name: "leather-handbag.jpg",      kind: "product-bag",       palette: ["#7a3a1f", "#4a2210"], bg: "linear-gradient(180deg, #efe6d4, #c9bda4)", w: 3000, h: 4000, bytes: 3_600_000, modified: "Mon · May 18", state: "done", ms: 77 },
  { id: "f11", name: "bonsai-juniper.jpg",       kind: "product-bonsai",    palette: ["#4a6a32", "#6b4a2a"], bg: "linear-gradient(180deg, #e6dec6, #b9aa83)", w: 4000, h: 3000, bytes: 4_400_000, modified: "Sun · May 17", state: "raw" },
  { id: "f12", name: "espresso-machine.heic",    kind: "product-machine",   palette: ["#1c1c1c", "#b4b4b4"], bg: "linear-gradient(180deg, #c5cdd5, #8b9aa9)", w: 3000, h: 3000, bytes: 5_120_000, modified: "Sun · May 17", state: "raw" },
  { id: "f13", name: "guitar-fender-tele.jpg",   kind: "product-guitar",    palette: ["#d59a2a", "#5a3a18"], bg: "linear-gradient(180deg, #2c2622, #1a1614)", w: 4000, h: 3000, bytes: 4_800_000, modified: "Sun · May 17", state: "raw" },
];

window.SAMPLE_FILES = SAMPLE_FILES;
