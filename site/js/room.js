// NiteLite's bedroom, live in the browser.
//
// room/room.glb comes from scene/export_web.py (Blender, Z-up). glTF is Y-up, so a
// Blender point (x, y, z) is (x, z, -y) here: see b(). Procedural surfaces arrive with
// placeholder materials and metre-scale UVs; MATERIALS below retextures them.
//
// Light mode is a sunny morning, dark mode is night with the bedside lamp on. Every
// NiteLite transition is an object in the room: it acts in full light, the picture
// dips to black, day and night swap (and so does the page theme), then it reopens.

import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { DRACOLoader } from "three/addons/loaders/DRACOLoader.js";
import { RGBELoader } from "three/addons/loaders/RGBELoader.js";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { CSS3DRenderer, CSS3DObject } from "three/addons/renderers/CSS3DRenderer.js";
import { RectAreaLightUniformsLib } from "three/addons/lights/RectAreaLightUniformsLib.js";

const DRACO = "https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/libs/draco/gltf/";
const root = document.documentElement;
const $ = (s) => document.querySelector(s);
const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)");
const systemDark = matchMedia("(prefers-color-scheme: dark)");
const deg = THREE.MathUtils.degToRad;

/** Blender coordinates (Z up) to three.js (Y up). */
const b = (x, y, z) => new THREE.Vector3(x, z, -y);

// ------------------------------------------------------------------ room facts (mirror scene/build_scene.py)

const ROOM = { x0: -2.8, x1: 2.6, y0: -3.6, y1: 2.0, h: 2.6 };
const WINDOW = { y0: 0.25, y1: 1.55, z0: 0.85, z1: 2.2 };
const DOOR = { x0: -2.62, x1: -1.86 };

// Camera shots: position, look-at, horizontal field of view (degrees)
const SHOTS = {
  wide: { pos: b(-0.35, -2.75, 1.25), target: b(0.05, 1.6, 0.92), hfov: 73.7 },
  tall: { pos: b(0.45, -1.7, 1.3), target: b(1.15, 1.8, 1.25), hfov: 64 }, // portrait screens: lamp + headline
  window: { pos: b(1.1, -0.9, 1.4), target: b(2.6, 0.9, 1.45), hfov: 61.9 },
  door: { pos: b(-1.99, 0.3, 1.2), target: b(-2.24, 2.0, 1.05), hfov: 61.9 },
  wall: { pos: b(-0.95, 0.55, 1.5), target: b(-0.95, 2.0, 1.55), hfov: 65 },
  nightstand: { pos: b(0.55, 0.55, 1.15), target: b(1.45, 1.7, 0.72), hfov: 55 },
};

const STATES = {
  day: {
    sun: 4.2, sunColor: 0xffe0b8, sunTravel: b(-0.78, 0.28, -0.42).normalize(),
    env: 0.3, bg: 1.0, hemi: 0.12, window: 2.5, lamp: 0, hall: 0, bulb: 0, shade: 0, screen: 0, blinds: 12, exposure: 0.9,
  },
  night: {
    sun: 0.45, sunColor: 0x8aa6ff, sunTravel: b(-0.7, 0.1, -0.55).normalize(),
    env: 0.04, bg: 0.12, hemi: 0.03, window: 0.18, lamp: 1.3, hall: 7, bulb: 10, shade: 1.1, screen: 0.8, blinds: 38, exposure: 1.05,
  },
};

// Placeholder material name → how to dress it. scale = texture repeats per metre.
const MATERIALS = {
  Floor: { tex: "wood_floor", scale: 0.45, roughness: 0.75, colorMap: true },
  Wall: { color: [0.82, 0.76, 0.66], tex: "plastered_wall_04", scale: 0.6, roughness: 1, bump: 0.6 },
  Ceiling: { color: [0.85, 0.83, 0.79], roughness: 0.9 },
  Hall: { color: [0.8, 0.72, 0.6], roughness: 0.9 },
  Trim: { color: [0.86, 0.84, 0.8], roughness: 0.35 },
  Door: { color: [0.84, 0.82, 0.77], roughness: 0.32 },
  Blind: { color: [0.8, 0.78, 0.74], roughness: 0.85 },
  Brass: { color: [0.85, 0.62, 0.3], roughness: 0.28, metalness: 1 },
  Velvet: { color: [0.11, 0.17, 0.4], tex: "velour_velvet", scale: 1.5, roughness: 1, sheen: [0.45, 0.55, 0.9], double: true },
  Headboard: { color: [0.95, 0.68, 0.2], tex: "velour_velvet", scale: 2, roughness: 1, sheen: [1, 0.85, 0.5] },
  Duvet: { color: [1, 0.97, 0.9], tex: "waffle_pique_cotton", scale: 2.5, roughness: 1, bump: 1.5, double: true },
  Sheet: { color: [0.9, 0.88, 0.84], roughness: 0.8 },
  Pillow: { color: [0.98, 0.95, 0.88], tex: "waffle_pique_cotton", scale: 3, roughness: 1, bump: 1 },
  Throw: { color: [0.1, 0.19, 0.4], tex: "knitted_fleece", scale: 2, roughness: 1, bump: 2, double: true },
  BedFrame: { color: [0.75, 0.45, 0.28], tex: "wood_floor", scale: 1.5, roughness: 0.6, colorMap: true },
  Walnut: { color: [0.2, 0.11, 0.06], roughness: 0.4, clearcoat: 0.2 },
  Ceramic: { color: [0.04, 0.09, 0.2], roughness: 0.15, clearcoat: 0.6 },
  Shade: { color: [1, 0.93, 0.8], tex: "rough_linen", scale: 6, roughness: 0.9, colorMap: true, double: true, emissive: [1, 0.68, 0.38] },
  Bulb: { color: [0.05, 0.05, 0.05], roughness: 0.3, emissive: [1, 0.78, 0.5] },
  PhoneBody: { color: [0.02, 0.02, 0.025], roughness: 0.15, clearcoat: 1 },
  PhoneScreen: { color: [0.01, 0.01, 0.01], roughness: 0.1, emissive: [0.55, 0.62, 1] },
  BookA: { color: [0.75, 0.2, 0.15], roughness: 0.6 },
  Rug: { color: [0.8, 0.55, 0.32], tex: "knitted_fleece", scale: 3, roughness: 1, bump: 2 },
  RugBorder: { color: [0.13, 0.19, 0.36], tex: "knitted_fleece", scale: 3, roughness: 1, bump: 2 },
  ArtMat: { color: [0.93, 0.9, 0.84], roughness: 0.8 },
};

// What each thing in the room does
const ACTIONS = {
  curtains: { label: "Draw the curtains", sub: "Curtain call" },
  blinds: { label: "Close the blinds", sub: "Venetian blinds" },
  tv: { label: "Switch off the TV", sub: "Old TV turn-off" },
  projector: { label: "Run the projector", sub: "Classic film iris" },
  door: { label: "Shut the door", sub: "Left-right wipe" },
  lamp: { label: "Pull the lamp chain", sub: "Switch modes" },
  book: { label: "Read the book", sub: "How to install" },
  phone: { label: "Download NiteLite", sub: "Free · macOS 13+" },
  clock: { label: "", sub: "" },
};

// ------------------------------------------------------------------ tiny tween engine

const tweens = new Set();
const ease = {
  in: (t) => t * t * t,
  out: (t) => 1 - Math.pow(1 - t, 3),
  inOut: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  linear: (t) => t,
};
function tween(dur, fn, curve = ease.inOut) {
  if (reduceMotion.matches) dur = Math.min(dur, 0.05);
  return new Promise((resolve) => {
    tweens.add({ start: performance.now(), dur: dur * 1000, fn, curve, resolve });
  });
}
function lerpTo(obj, key, to, dur, curve) {
  const from = obj[key];
  return tween(dur, (t) => { obj[key] = from + (to - from) * t; }, curve);
}
const wait = (s) => new Promise((r) => setTimeout(r, reduceMotion.matches ? 0 : s * 1000));
function stepTweens(now) {
  for (const tw of tweens) {
    const t = Math.min(1, (now - tw.start) / tw.dur);
    tw.fn(tw.curve(t));
    if (t >= 1) { tweens.delete(tw); tw.resolve(); }
  }
}

// ------------------------------------------------------------------ setup

const canvas = $("#gl");
let renderer;
try {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: "high-performance" });
} catch (e) {
  document.body.classList.add("flat");
  throw e;
}
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.75));
renderer.toneMapping = THREE.AgXToneMapping;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.shadowMap.autoUpdate = false;
RectAreaLightUniformsLib.init();

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(50, 1, 0.05, 200);
const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.45, 0.55, 0.92);
composer.addPass(bloom);
composer.addPass(new OutputPass());

const cssRenderer = new CSS3DRenderer({ element: $("#css3d") });

let night = root.dataset.theme ? root.dataset.theme === "dark" : systemDark.matches;
let busy = false;
let shadowsLive = 30; // frames of shadow updates still to render
const nodes = {};

// ------------------------------------------------------------------ loading

const manager = new THREE.LoadingManager();
manager.onProgress = (_, loaded, total) => { $("#loading").textContent = `Setting up the room… ${Math.round((loaded / total) * 100)}%`; };
const texLoader = new THREE.TextureLoader(manager);
const draco = new DRACOLoader().setDecoderPath(DRACO);
const gltfLoader = new GLTFLoader(manager).setDRACOLoader(draco);
const hdrLoader = new RGBELoader(manager);
const pmrem = new THREE.PMREMGenerator(renderer);

const texCache = {};
function texture(name, kind, scale, srgb) {
  const key = `${name}_${kind}`;
  texCache[key] ??= texLoader.load(`room/tex/${key}.jpg`);
  const t = texCache[key].clone();
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(scale, scale);
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  t.anisotropy = 8;
  // clone() shares the image; mark for upload once it arrives
  const src = texCache[key];
  if (src.image) t.needsUpdate = true; else src.addEventListener?.("load", () => (t.needsUpdate = true));
  return t;
}

function dress(mesh) {
  const spec = MATERIALS[mesh.material?.name];
  if (!spec) return;
  const params = { roughness: spec.roughness ?? 0.6, metalness: spec.metalness ?? 0 };
  if (spec.color) params.color = new THREE.Color(...spec.color);
  if (spec.tex) {
    if (spec.colorMap) params.map = texture(spec.tex, "diffuse", spec.scale, true);
    params.roughnessMap = texture(spec.tex, "rough", spec.scale, false);
    if (spec.bump) { params.bumpMap = params.roughnessMap; params.bumpScale = spec.bump; }
  }
  if (spec.emissive) { params.emissive = new THREE.Color(...spec.emissive); params.emissiveIntensity = 0; if (params.map) params.emissiveMap = params.map; }
  if (spec.double) params.side = THREE.DoubleSide;
  let mat;
  if (spec.sheen || spec.clearcoat) {
    mat = new THREE.MeshPhysicalMaterial({ ...params, sheenRoughness: 0.45, clearcoat: spec.clearcoat ?? 0 });
    if (spec.sheen) { mat.sheen = 1; mat.sheenColor.setRGB(...spec.sheen); }
  } else {
    mat = new THREE.MeshStandardMaterial(params);
  }
  mat.name = mesh.material.name;
  mesh.material = mat;
}

// ------------------------------------------------------------------ lights

const sun = new THREE.DirectionalLight(0xffffff, 1);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -4, right: 4, top: 4, bottom: -4, near: 0.5, far: 20 });
sun.shadow.bias = -0.0003;
sun.shadow.normalBias = 0.015;
const sunTarget = new THREE.Object3D();
sunTarget.position.copy(b(0.3, 0.6, 0.8));
sun.target = sunTarget;
scene.add(sun, sunTarget);

const hemi = new THREE.HemisphereLight(0xdde6ff, 0x6b4f37, 0.3);
scene.add(hemi);

// Soft skylight through the window (no shadows; the sun does those)
const windowLight = new THREE.RectAreaLight(0xe6eeff, 1, WINDOW.y1 - WINDOW.y0, WINDOW.z1 - WINDOW.z0);
windowLight.position.copy(b(ROOM.x1 - 0.02, (WINDOW.y0 + WINDOW.y1) / 2, (WINDOW.z0 + WINDOW.z1) / 2));
windowLight.lookAt(b(-3, (WINDOW.y0 + WINDOW.y1) / 2, 1.2));
scene.add(windowLight);

const lampLight = new THREE.PointLight(0xffb36b, 0, 0, 2);
lampLight.castShadow = true;
lampLight.shadow.mapSize.set(1024, 1024);
lampLight.shadow.camera.near = 0.03;
lampLight.shadow.bias = -0.002;
scene.add(lampLight);

const hallLight = new THREE.SpotLight(0xffc98a, 0, 7, deg(34), 0.8, 1.8);
hallLight.position.copy(b((DOOR.x0 + DOOR.x1) / 2, 3.0, 2.3));
hallLight.target.position.copy(b(-1.9, 0.6, 0));
hallLight.castShadow = true;
hallLight.shadow.mapSize.set(1024, 1024);
scene.add(hallLight, hallLight.target);

const tvLight = new THREE.PointLight(0x9cc3ff, 0, 3.5, 2);
const projLight = new THREE.SpotLight(0xffe7c2, 0, 6, deg(22), 0.35, 1.2);
scene.add(tvLight, projLight, projLight.target);

// ------------------------------------------------------------------ screens: the TV and the projector's picture

const tvMaterial = new THREE.ShaderMaterial({
  transparent: true, depthWrite: false,
  uniforms: { power: { value: 0 }, sx: { value: 1 }, sy: { value: 1 }, dotv: { value: 0 }, time: { value: 0 } },
  vertexShader: "varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }",
  fragmentShader: `
    varying vec2 vUv; uniform float power, sx, sy, dotv, time;
    float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
    void main(){
      vec2 c = vUv - 0.5;
      float rect = step(abs(c.x) * 2.0, sx) * step(abs(c.y) * 2.0, sy);
      float stat = 0.65 + 0.35 * hash(floor(vUv * vec2(160.0, 120.0)) + floor(time * 24.0));
      float lines = 0.8 + 0.2 * sin(vUv.y * 600.0);
      vec3 col = vec3(0.62, 0.78, 1.0) * stat * lines * 1.6;
      float glow = max(0.0, 1.0 - length(vec2(c.x, c.y * 0.75)) / 0.06) * dotv;
      gl_FragColor = vec4(col * rect * power + vec3(1.0) * glow * 4.0, clamp(rect * power + glow, 0.0, 1.0));
    }`,
});

const projMaterial = new THREE.ShaderMaterial({
  transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  uniforms: { power: { value: 0 }, iris: { value: 1 }, time: { value: 0 } },
  vertexShader: "varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }",
  fragmentShader: `
    varying vec2 vUv; uniform float power, iris, time;
    float hash(float p){ return fract(sin(p * 91.345) * 47453.5453); }
    void main(){
      vec2 c = vUv - 0.5; c.y *= 0.58;
      float d = length(c);
      float inside = smoothstep(iris * 0.6 + 0.004, iris * 0.6 - 0.004, d);
      float vign = 1.0 - d * 0.9;
      float flicker = 0.93 + 0.07 * hash(floor(time * 18.0));
      vec3 col = vec3(1.0, 0.93, 0.78) * 2.2 * vign * flicker;
      gl_FragColor = vec4(col * inside * power, 1.0);
    }`,
});

// ------------------------------------------------------------------ state: day or night

function applyLighting(isNight) {
  const s = isNight ? STATES.night : STATES.day;
  sun.intensity = s.sun;
  sun.color.set(s.sunColor);
  sun.position.copy(sunTarget.position).addScaledVector(s.sunTravel, -9);
  scene.environment = isNight ? envNight : envDay;
  scene.background = isNight ? skyNight : skyDay;
  scene.environmentIntensity = s.env;
  scene.backgroundIntensity = s.bg;
  hemi.intensity = s.hemi;
  windowLight.intensity = s.window;
  windowLight.color.set(isNight ? 0x6f86c9 : 0xe6eeff);
  lampLight.intensity = s.lamp;
  hallLight.intensity = s.hall;
  for (const m of [nodes.mat.Bulb, nodes.mat.Shade, nodes.mat.PhoneScreen]) {
    if (m) m.emissiveIntensity = m.name === "Bulb" ? s.bulb : m.name === "Shade" ? s.shade : s.screen;
  }
  setBlinds(s.blinds);
  renderer.toneMappingExposure = s.exposure;
  shadowsLive = 3;
}

function setTheme(isNight) {
  night = isNight;
  root.dataset.theme = isNight ? "dark" : "light";
  try { localStorage.setItem("nitelite-theme", root.dataset.theme); } catch (e) {}
  $("#toggle").setAttribute("aria-label", `Pull the lamp chain: switch to ${isNight ? "Light" : "Dark"} Mode`);
  $("#status").textContent = isNight ? "Night. Dark Mode." : "Morning. Light Mode.";
}

function swap() {
  setTheme(!night);
  applyLighting(night);
}

// ------------------------------------------------------------------ the room's moving parts

function setBlinds(tilt) {
  for (const s of nodes.slats) s.rotation.set(0, 0, -deg(tilt));
  shadowsLive = Math.max(shadowsLive, 2);
}
function setCurtains(v) {
  for (const c of nodes.curtains) c.morphTargetInfluences[0] = v;
  shadowsLive = Math.max(shadowsLive, 2);
}

// Camera: a base shot that transitions tween, plus a little look-around from the pointer
const cam = { pos: new THREE.Vector3(), target: new THREE.Vector3(), hfov: 70 };
const look = { x: 0, y: 0, tx: 0, ty: 0, drag: 0 };
function restShot() { return innerWidth / innerHeight < 0.9 ? SHOTS.tall : SHOTS.wide; }
function setShot(shot) { cam.pos.copy(shot.pos); cam.target.copy(shot.target); cam.hfov = shot.hfov; }
function moveTo(shot, dur, curve = ease.inOut) {
  const p0 = cam.pos.clone(), t0 = cam.target.clone(), f0 = cam.hfov;
  return tween(dur, (t) => {
    cam.pos.lerpVectors(p0, shot.pos, t);
    cam.target.lerpVectors(t0, shot.target, t);
    cam.hfov = f0 + (shot.hfov - f0) * t;
  }, curve);
}
const _off = new THREE.Vector3();
function updateCamera() {
  look.x += (look.tx - look.x) * 0.06;
  look.y += (look.ty - look.y) * 0.06;
  const aspect = innerWidth / innerHeight;
  let vfov = 2 * Math.atan(Math.tan(deg(cam.hfov) / 2) / aspect);
  vfov = Math.min(vfov, deg(72));
  camera.fov = THREE.MathUtils.radToDeg(vfov);
  camera.aspect = aspect;
  // Orbit the camera a little around its target
  _off.subVectors(cam.pos, cam.target);
  const sph = new THREE.Spherical().setFromVector3(_off);
  sph.theta += look.x + look.drag;
  sph.phi = THREE.MathUtils.clamp(sph.phi + look.y, 0.6, 2.4);
  camera.position.copy(cam.target).add(_off.setFromSpherical(sph));
  camera.lookAt(cam.target);
  camera.updateProjectionMatrix();
}

const dip = (dur = 0.28) => Promise.all([lerpTo(renderer, "toneMappingExposure", 0, dur, ease.in), fadeWall(0, dur)]);
const rise = (dur = 0.45) => {
  const target = (night ? STATES.night : STATES.day).exposure;
  renderer.toneMappingExposure = 0;
  return Promise.all([lerpTo(renderer, "toneMappingExposure", target, dur, ease.out), fadeWall(1, dur)]);
};
function fadeWall(to, dur) {
  const el = $("#css3d");
  const from = parseFloat(el.style.opacity || "1");
  return tween(dur, (t) => { el.style.opacity = String(from + (to - from) * t); });
}

// Each transition: act in full light → dip to black → swap day/night → reopen
const TRANSITIONS = {
  async curtains() {
    const nudge = { pos: cam.pos.clone().add(b(0.25, 0.35, 0)), target: cam.target.clone().add(b(0.5, 0, 0)), hfov: cam.hfov };
    const back = { pos: cam.pos.clone(), target: cam.target.clone(), hfov: cam.hfov };
    await Promise.all([tween(0.9, setCurtains, ease.inOut), moveTo(nudge, 1.1)]);
    await dip(); swap(); await wait(0.12);
    await Promise.all([rise(), tween(1.0, (t) => setCurtains(1 - t), ease.inOut), moveTo(back, 1.1)]);
  },
  async blinds() {
    const from = (night ? STATES.night : STATES.day).blinds;
    const back = restShot();
    await Promise.all([moveTo(SHOTS.window, 0.7)]);
    await tween(0.45, (t) => setBlinds(from + (88 - from) * t), ease.in);
    await dip(0.22); swap(); await wait(0.12);
    const to = (night ? STATES.night : STATES.day).blinds;
    setBlinds(88);
    await Promise.all([rise(), tween(0.6, (t) => setBlinds(88 + (to - 88) * t), ease.out)]);
    await moveTo(back, 0.8);
  },
  async tv() {
    const u = tvMaterial.uniforms;
    const back = restShot();
    u.sx.value = u.sy.value = 1; u.dotv.value = 0;
    await Promise.all([moveTo(nodes.tvShot, 0.75), tween(0.15, (t) => { u.power.value = t; tvLight.intensity = t * 1.5; })]);
    await wait(0.12);
    await tween(0.1, (t) => { u.sy.value = 1 - t * 0.988; }, ease.in);
    await Promise.all([tween(0.1, (t) => { u.sx.value = 1 - t; }, ease.in), tween(0.1, (t) => { u.dotv.value = t; })]);
    tvLight.intensity = 0;
    await Promise.all([tween(0.18, (t) => { u.dotv.value = 1 - t; }), dip(0.18)]);
    swap(); await wait(0.15);
    await Promise.all([rise(0.3), tween(0.08, (t) => { u.dotv.value = t * 0.9; })]);
    await Promise.all([tween(0.1, (t) => { u.sx.value = t; u.dotv.value = 0.9 * (1 - t); })]);
    await tween(0.12, (t) => { u.sy.value = 0.012 + t * 0.988; tvLight.intensity = t * 1.5; });
    await wait(0.3);
    await Promise.all([moveTo(back, 0.8), tween(0.35, (t) => { u.power.value = 1 - t; tvLight.intensity = 1.5 * (1 - t); })]);
  },
  async projector() {
    const u = projMaterial.uniforms;
    const back = restShot();
    u.iris.value = 1;
    await Promise.all([moveTo(SHOTS.wall, 0.8), tween(0.25, (t) => { u.power.value = t; projLight.intensity = t * 18; })]);
    await tween(0.65, (t) => { u.iris.value = 1 - t; projLight.intensity = 18 * (1 - t); }, ease.in);
    await dip(0.22); swap(); await wait(0.12);
    projLight.intensity = 0;
    await Promise.all([rise(), tween(0.7, (t) => { u.iris.value = t; projLight.intensity = 18 * t; }, ease.out)]);
    await wait(0.15);
    await Promise.all([moveTo(back, 0.8), tween(0.35, (t) => { u.power.value = 1 - t; projLight.intensity = 18 * (1 - t); })]);
  },
  async door() {
    const hinge = nodes.door;
    const open = deg(-18);
    const back = restShot();
    await moveTo(SHOTS.door, 0.7);
    await tween(0.45, (t) => { hinge.rotation.y = open * (1 - t); shadowsLive = 2; }, ease.in);
    await dip(0.2); swap(); await wait(0.12);
    await Promise.all([rise(), tween(0.7, (t) => { hinge.rotation.y = open * t; shadowsLive = 2; }, ease.out)]);
    await moveTo(back, 0.8);
  },
  async lamp() {
    const pull = nodes.chain;
    const y0 = pull.position.y;
    await tween(0.12, (t) => { pull.position.y = y0 - 0.02 * t; }, ease.out);
    await dip(0.12); swap();
    await Promise.all([rise(0.35), tween(0.2, (t) => { pull.position.y = y0 - 0.02 * (1 - t); }, ease.out)]);
  },
};

async function play(name) {
  if (busy || !TRANSITIONS[name]) return;
  busy = true;
  document.body.classList.remove("hovering");
  hideTip();
  try {
    await TRANSITIONS[name]();
  } finally {
    busy = false;
  }
}

// ------------------------------------------------------------------ the alarm clock tells the real time

function setupClock(clockRoot) {
  const hands = ["houd_hand", "minute_hand", "second_hand"].map((n) => clockRoot.getObjectByName(n)).filter(Boolean);
  // In the clock root's space the face looks along +Z (toward the room) with 12 o'clock up
  const N = new THREE.Vector3(0, 0, 1), U = new THREE.Vector3(0, 1, 0), R = new THREE.Vector3(1, 0, 0);
  const rigs = hands.map((h) => {
    h.geometry.computeBoundingBox();
    const bb = h.geometry.boundingBox;
    const size = bb.getSize(new THREE.Vector3());
    const axes = ["x", "y", "z"];
    const thin = axes.reduce((a, c) => (size[c] < size[a] ? c : a));
    const rest = axes.filter((a) => a !== thin);
    const reach = (a) => Math.max(Math.abs(bb.max[a]), Math.abs(bb.min[a]));
    const along = rest.reduce((a, c) => (reach(c) > reach(a) ? c : a));
    const pointer = new THREE.Vector3(); pointer[along] = Math.abs(bb.max[along]) >= Math.abs(bb.min[along]) ? 1 : -1;
    const normal = new THREE.Vector3(); normal[thin] = 1;
    if (normal.clone().applyQuaternion(h.quaternion).dot(N) < 0) normal.negate();
    const local = new THREE.Matrix4().makeBasis(pointer, normal, new THREE.Vector3().crossVectors(pointer, normal));
    return { h, localInv: local.invert() };
  });
  return () => {
    const d = new Date();
    const s = d.getSeconds() + d.getMilliseconds() / 1000;
    const m = d.getMinutes() + s / 60;
    const hr = (d.getHours() % 12) + m / 60;
    const angles = [hr / 12, m / 60, s / 60].map((f) => f * Math.PI * 2);
    rigs.forEach(({ h, localInv }, i) => {
      const dir = U.clone().multiplyScalar(Math.cos(angles[i])).addScaledVector(R, Math.sin(angles[i]));
      const target = new THREE.Matrix4().makeBasis(dir, N, new THREE.Vector3().crossVectors(dir, N));
      h.quaternion.setFromRotationMatrix(target.multiply(localInv));
    });
  };
}

// ------------------------------------------------------------------ build the scene once everything loads

let envDay, envNight, skyDay, skyNight, tickClock = () => {};

async function load() {
  const [gltf, hdrDay, hdrNight] = await Promise.all([
    gltfLoader.loadAsync("room/room.glb"),
    hdrLoader.loadAsync("room/kloofendal_48d_partly_cloudy_puresky_1k.hdr"),
    hdrLoader.loadAsync("room/qwantani_moonrise_puresky_1k.hdr"),
  ]);
  for (const [hdr, rot] of [[hdrDay, 200], [hdrNight, 90]]) hdr.mapping = THREE.EquirectangularReflectionMapping;
  skyDay = hdrDay; skyNight = hdrNight;
  envDay = pmrem.fromEquirectangular(hdrDay).texture;
  envNight = pmrem.fromEquirectangular(hdrNight).texture;
  scene.backgroundRotation.set(0, deg(-110), 0);
  scene.environmentRotation.set(0, deg(-110), 0);

  const room = gltf.scene;
  nodes.mat = {};
  room.traverse((o) => {
    if (!o.isMesh) return;
    o.castShadow = o.receiveShadow = true;
    dress(o);
    if (o.material?.name) nodes.mat[o.material.name] = o.material;
  });
  scene.add(room);

  nodes.slats = [];
  room.getObjectByName("Blinds").traverse((o) => { if (/^Slat\d+/.test(o.name) && !o.isMesh) nodes.slats.push(o); });
  if (!nodes.slats.length) room.getObjectByName("Blinds").traverse((o) => { if (/^Slat\d+/.test(o.name)) nodes.slats.push(o); });
  nodes.curtains = ["CurtainL", "CurtainR"].map((n) => { const o = room.getObjectByName(n); return o.isMesh ? o : o.children.find((c) => c.isMesh); });
  nodes.door = room.getObjectByName("DoorHinge");
  nodes.chain = room.getObjectByName("ChainPull");

  // Lamp light sits at the bulb
  const bulb = room.getObjectByName("LampBulb");
  bulb.updateWorldMatrix(true, false);
  new THREE.Box3().setFromObject(bulb).getCenter(lampLight.position);
  bulb.castShadow = false;
  room.getObjectByName("LampShade").castShadow = true;

  // TV glow plane over the screen, in the TV's own space (Blender local (-0.072, -0.218, 0.262))
  const tv = room.getObjectByName("Television_01_root");
  const tvScreen = new THREE.Mesh(new THREE.PlaneGeometry(0.37, 0.285), tvMaterial);
  tvScreen.position.set(-0.072, 0.262, 0.219);
  tv.add(tvScreen);
  tv.updateWorldMatrix(true, true);
  const sc = tvScreen.getWorldPosition(new THREE.Vector3());
  tvLight.position.copy(sc).add(new THREE.Vector3(0, 0, 0.25));
  nodes.tvShot = { pos: sc.clone().add(new THREE.Vector3(-0.04, 0.02, 0.42)), target: sc, hfov: 61.9 };

  // Projector picture on the back wall above the TV
  const pic = new THREE.Mesh(new THREE.PlaneGeometry(1.2, 0.69), projMaterial);
  pic.position.copy(b(-0.95, ROOM.y1 - 0.004, 1.55));
  scene.add(pic);
  const proj = room.getObjectByName("filmstrip_projector_8mm_root");
  projLight.position.copy(proj.getWorldPosition(new THREE.Vector3())).add(new THREE.Vector3(0, 0.22, 0));
  projLight.target.position.copy(pic.position);

  // Ground outside the window, so nothing below the horizon glows in
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), new THREE.MeshStandardMaterial({ color: 0x223018, roughness: 1 }));
  ground.rotation.x = -Math.PI / 2;
  ground.position.copy(b(ROOM.x1 + 200.2, 0, -0.5));
  ground.receiveShadow = true;
  scene.add(ground);

  tickClock = setupClock(room.getObjectByName("alarm_clock_01_root"));

  // Clickable things: map meshes to actions by their ancestors
  const tag = (name, action) => room.getObjectByName(name)?.traverse((o) => { if (o.isMesh) o.userData.action = action; });
  ["CurtainL", "CurtainR", "CurtainRod"].forEach((n) => tag(n, "curtains"));
  ["Blinds", "WinFrameTop", "WinFrameBot", "WinFrameL", "WinFrameR", "WinMullion", "WinTransom"].forEach((n) => tag(n, "blinds"));
  tag("Television_01_root", "tv");
  tag("filmstrip_projector_8mm_root", "projector");
  ["DoorHinge", "DoorCasingL", "DoorCasingR", "DoorCasingTop"].forEach((n) => tag(n, "door"));
  tag("Lamp", "lamp");
  tag("BookA", "book");
  tag("Phone", "phone");
  tag("alarm_clock_01_root", "clock");
  tvScreen.userData.action = "tv";

  // Words on the wall above the lamp: 1 CSS pixel = 1.18 mm
  const wall = new CSS3DObject($("#wall"));
  wall.position.copy(b(1.55, ROOM.y1 - 0.01, 1.78));
  wall.scale.setScalar(0.00118);
  scene.add(wall);

  applyLighting(night);
  setTheme(night);
  setShot(restShot());
  resize();
  document.body.classList.add("ready");
}

// ------------------------------------------------------------------ interaction

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const tip = $("#tip");
let hovered = null;
function pick(x, y) {
  pointer.set((x / innerWidth) * 2 - 1, -(y / innerHeight) * 2 + 1);
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.intersectObject(scene, true).find((h) => h.object.visible);
  return hit?.object.userData.action ?? null;
}
function showTip(action, x, y) {
  const a = ACTIONS[action];
  if (action === "clock") {
    tip.innerHTML = `${new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}<small>It's the real time</small>`;
  } else {
    tip.innerHTML = `${a.label}<small>${a.sub}</small>`;
  }
  tip.style.left = `${x}px`;
  tip.style.top = `${y}px`;
  tip.classList.add("on");
}
function hideTip() { tip.classList.remove("on"); }
function highlight(action) {
  document.querySelectorAll(".legend [data-transition]").forEach((el) => el.classList.toggle("hot", el.dataset.transition === action));
}

canvas.addEventListener("pointermove", (e) => {
  if (e.pointerType === "mouse") {
    look.tx = -((e.clientX / innerWidth) * 2 - 1) * 0.06;
    look.ty = -((e.clientY / innerHeight) * 2 - 1) * 0.035;
  }
  if (busy || !document.body.classList.contains("ready")) return;
  const action = pick(e.clientX, e.clientY);
  if (action !== hovered) { hovered = action; highlight(action); }
  document.body.classList.toggle("hovering", !!action && action !== "clock");
  if (action) showTip(action, e.clientX, e.clientY); else hideTip();
});
canvas.addEventListener("pointerleave", () => { look.tx = look.ty = 0; hideTip(); highlight(null); });

// Touch: drag to look around, tap to use
let drag = null;
canvas.addEventListener("pointerdown", (e) => { drag = { x: e.clientX, start: look.drag, moved: false }; });
canvas.addEventListener("pointerup", (e) => {
  const moved = drag?.moved;
  drag = null;
  if (moved || busy) return;
  const action = pick(e.clientX, e.clientY);
  if (action) act(action);
});
addEventListener("pointermove", (e) => {
  if (!drag || e.pointerType === "mouse") return;
  const dx = e.clientX - drag.x;
  if (Math.abs(dx) > 6) drag.moved = true;
  look.drag = THREE.MathUtils.clamp(drag.start - dx * 0.004, -0.55, 0.55);
});

function act(action) {
  if (action === "phone") { location.href = "NiteLite.zip"; return; }
  if (action === "book") { openBook(); return; }
  if (action === "clock") return;
  play(action);
}

async function openBook() {
  if (busy) return;
  $("#book").hidden = false;
  $("#book .close").focus();
  if (!reduceMotion.matches) await moveTo(SHOTS.nightstand, 0.9);
}
async function closeBook() {
  $("#book").hidden = true;
  await moveTo(restShot(), 0.8);
}

document.addEventListener("click", (e) => {
  const t = e.target.closest("[data-transition], [data-action]");
  if (!t) return;
  if (t.dataset.transition) play(t.dataset.transition);
  else if (t.dataset.action === "install") openBook();
  else if (t.dataset.action === "close-book") closeBook();
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !$("#book").hidden) closeBook();
  if (e.key.toLowerCase() === "d" && !e.metaKey && !e.ctrlKey && !e.altKey && !e.target.closest("input, textarea")) play("lamp");
});

// ------------------------------------------------------------------ loop

function resize() {
  renderer.setSize(innerWidth, innerHeight, false);
  composer.setSize(innerWidth, innerHeight);
  cssRenderer.setSize(innerWidth, innerHeight);
  if (!busy && $("#book").hidden) setShot(restShot());
}
addEventListener("resize", resize);

const clockEl = $("#clock");
let lastClock = 0;
function frame(now) {
  stepTweens(now);
  if (reduceMotion.matches) { look.tx = look.ty = 0; }
  updateCamera();
  const t = now / 1000;
  tvMaterial.uniforms.time.value = t;
  projMaterial.uniforms.time.value = t;
  tickClock();
  if (now - lastClock > 1000) {
    lastClock = now;
    clockEl.textContent = new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  }
  if (shadowsLive > 0 || tweens.size) { renderer.shadowMap.needsUpdate = true; shadowsLive = Math.max(0, shadowsLive - 1); }
  composer.render();
  cssRenderer.render(scene, camera);
  requestAnimationFrame(frame);
}

load().then(() => requestAnimationFrame(frame)).catch((err) => {
  console.error(err);
  document.body.classList.add("flat");
});
