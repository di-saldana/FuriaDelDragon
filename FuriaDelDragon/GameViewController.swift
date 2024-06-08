//
//  GameViewController.swift
//  FuriaDelDragon
//
//  Created by Dianelys Saldaña on 5/24/24.
//

import UIKit
import QuartzCore
import SceneKit
import SpriteKit
import CoreMotion

class GameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
    var scene : SCNScene?
    var motion : CMMotionManager = CMMotionManager()
    var velocity : Float = 0.0
    var cameraNode : SCNNode?
    var cameraEulerAngle : SCNVector3?
    var limits : CGRect = CGRect.zero
    var iceballModel : SCNNode?
    var previousUpdateTime : TimeInterval?
    let spawnInterval : Float = 1.0 // 0.25
    var timeToSpawn : TimeInterval = 1.0
    
    let categoryMaskDragon = 0b001 // (1)
    let categoryMaskShot = 0b010 // (2)
    let categoryMaskIceBall = 0b100 // (4)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Instantiate scene
        self.scene = SCNScene(named: "art.scnassets/dragon.scn")!

        // Obtener el nodo "camara" de la escena, y almacenar su orientación original (eulerAngles)
        guard let cameraNode = scene?.rootNode.childNode(withName: "camera", recursively: true) else {
            fatalError("Camera node not found in the scene.")
        }
        self.cameraNode = cameraNode
        self.cameraEulerAngle = cameraNode.eulerAngles
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene?.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene?.rootNode.addChildNode(ambientLightNode)
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = scene
        
        // configure the view
        scnView.backgroundColor = UIColor.black
        
        // Asignar esta clase como delegado del renderer de la escena, y activar la propiedad `isPlaying` de la vista
        scnView.delegate = self
        scnView.isPlaying = true
        
        startMotionUpdates()
        startTapRecognition(inView: scnView)
        setupIceBalls(forView: scnView)
        
        scene?.physicsWorld.contactDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let scnView = self.view as! SCNView
        
        setupLimits(forView: scnView)
    }
    
    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        // retrieve the SCNView
//        let scnView = self.view as! SCNView
//
//        // check what nodes are tapped
//        let p = gestureRecognize.location(in: scnView)
//        let hitResults = scnView.hitTest(p, options: [:])
//        // check that we clicked on at least one object
//        if hitResults.count > 0 {
//            // retrieved the first clicked object
//            let result = hitResults[0]
//
//            // get its material
//            let material = result.node.geometry!.firstMaterial!
//
//            // highlight it
//            SCNTransaction.begin()
//            SCNTransaction.animationDuration = 0.5
//
//            // on completion - unhighlight
//            SCNTransaction.completionBlock = {
//                SCNTransaction.begin()
//                SCNTransaction.animationDuration = 0.5
//
//                material.emission.contents = UIColor.black
//
//                SCNTransaction.commit()
//            }
//
//            shot()
//            material.emission.contents = UIColor.red
//
//            SCNTransaction.commit()
//        }
        
        print("Screen tapped")
        shot()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    func startTapRecognition(inView view: SCNView) {
        // Programacion de un UITapGestureRecognizer y se agrego a la vista (view)
        // Se creo un gesto de reconocimiento de toque
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        
        // Se añadio el gesto de reconocimiento de toque a la vista SCN
        view.addGestureRecognizer(tapGesture)
    }
    
    func startMotionUpdates() {
        // Comprobar en self.motion is Device Motion esta disponible
        // Programar el intervalo de refreso de Device Motion updates en 1.0 / 60.0
        // Comenzamos la lectura de Device Motion updates
        // Hacemos que el ángulo de giro "roll" sea la velocidad (self.velocity) de nuestra nave
        // Orientamos la cámara utilizando pitch (eulerAngles.x) y roll (eurlerAngles.z)
        
        if(self.motion.isDeviceMotionAvailable) {
            self.motion.deviceMotionUpdateInterval = 1.0/60.0
            self.motion.startDeviceMotionUpdates(
                    to: OperationQueue.main,
                    withHandler: { (deviceMotion, error)
                                                  -> Void in

                if let roll = deviceMotion?.attitude.roll,
                    let pitch = deviceMotion?.attitude.pitch {
                    self.velocity = Float(roll)
                    
                    if let cameraNode = self.cameraNode,
                        let euler = self.cameraEulerAngle {
                        cameraNode.eulerAngles.z =
                           euler.z - Float(roll) * 0.1
                        cameraNode.eulerAngles.x =
                           euler.x - Float(pitch - 0.75) * 0.1
                    }
                }
            })
        }
    }
    
    func shot() {
        // Recuperar el nodo del dragon
        guard let dragonNode = scene?.rootNode.childNode(withName: "dragon", recursively: true) else {
            print("Dragon node not found in the scene.")
            return
        }
        
        // Load bullet
        guard let bulletScene = SCNScene(named: "art.scnassets/bullet.scn"),
              let bulletNode = bulletScene.rootNode.childNode(withName: "bullet", recursively: true)?.clone() else {
            fatalError("Failed to load or clone bullet scene.")
        }
        bulletNode.position = dragonNode.position
        
        // Agregamos el nodo a la escena
        scene?.rootNode.addChildNode(bulletNode)
        
        // Definimos una accion que mueva la bala 150 unidades negativas en el eje Z, y tras ello elimine la bala de la escena
        let moveAction = SCNAction.moveBy(x: 0, y: 0, z: -150, duration: 1.5)
        let removeAction = SCNAction.removeFromParentNode()
        let sequenceAction = SCNAction.sequence([moveAction, removeAction])
        
        // Ejecutamos la accion sobre la bala
        bulletNode.runAction(sequenceAction)
    }
    
    func setupLimits(forView view: SCNView) {
        // Calcular y almacenar en `self.limits` el rectángulo que defina los límites de la zona "jugable" dentro del plano XZ de la escena, donde la nave, disparos y asteroides se puedan mover sin salirse de los límites de la pantalla.
        let projectedOrigin = view.projectPoint(SCNVector3Zero)
        let unprojectedLeft = view.unprojectPoint(
                SCNVector3Make(0,
                               projectedOrigin.y,
                               projectedOrigin.z))
        let halfWidth = CGFloat(abs(unprojectedLeft.x))
        self.limits = CGRect(x: -halfWidth, y: -150,
                             width: halfWidth*2,
                             height: 200)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Calcular el delta time tomando como referencia previousUpdateTime, y actualizar previousUpdateTime
        let deltaTime = time - (previousUpdateTime ?? time)
        previousUpdateTime = time
        
        // Print dragon position
        if let dragonPosition = cameraNode?.position {
            print("Dragon Position: \(dragonPosition)")
        }
        
        // Mueve la nave lateralmente a partir de `velocity * 200` y el deltatime, evita que se salga de los limites de pantalla (`limits`) y gira la nave en el eje Z según el valor de `velocity`
        
        // Calcular la nueva posición X de la nave
        let newXPosition = cameraNode!.position.x + velocity * 200 * Float(deltaTime)
        
        // Limitar la nueva posición dentro de los límites de la pantalla
        let minX = Float(limits.minX)
        let maxX = Float(limits.maxX)
        let clampedX = min(maxX, max(minX, newXPosition))
        
        // Actualizar la posición X de la nave
        cameraNode!.position.x = clampedX
        
        // Girar la nave en el eje Z según el valor de velocity
        cameraNode!.eulerAngles.z = cameraEulerAngle!.z - velocity * 0.1
        
        // TODO [C03]: Spawn de ice balls
        //  - Descontamos el deltatime de timeToSpawn, y cuando este llegue a 0 generamos un nuevo ice ball y restablecemos el valor de timeToSpawn a spawnInterval.
        //  - El ice ball debe generarse en una posicion X aleatoria entre los limites de la escena (limits.minX y limits.maxX), Y=0, y Z=limits.minY
        timeToSpawn -= deltaTime
        if timeToSpawn <= 0 {
            // Generate a new ice ball at a random X position within the scene limits
            let randomX = CGFloat(Float.getRandom(from: Float(limits.minX), to: Float(limits.maxX)))
            let iceBallPosition = SCNVector3(x: Float(randomX), y: 0, z: Float(limits.minY))
            spawnIceBall(pos: iceBallPosition)
            
            // Print ice ball position
            print("Ice Ball Position: \(iceBallPosition)")
            
            // Reset the timeToSpawn
            timeToSpawn = TimeInterval(spawnInterval)
        }
    }
    
    func setupIceBalls(forView view: SCNView) {
        // Precarga el modelo ice_ball de ice_ball.scn, asignalo al campo iceballModel, y preparalo para su visualización en view
        let iceballScene = SCNScene(named: "art.scnassets/ice_ball.scn")
        self.iceballModel = iceballScene?.rootNode
            .childNode(withName: "ice_ball",
                       recursively: false)
        view.prepare(self.iceballModel!, shouldAbortBlock: nil)
    }
    
    func spawnIceBall(pos: SCNVector3) {
        // Clonar el iceBall "iceballModel"
        guard let iceBall = iceballModel?.clone() else {
            fatalError("Failed to clone ice ball model.")
        }
        
        // Agregar el nuevo ice ball a la escena (nodo raiz)
        scene?.rootNode.addChildNode(iceBall)
        
        // Situarlo en pos
        iceBall.position = pos
        
        // Hacer que se mueva hasta (pos.x, 0, limits.maxY) en 3 segundos
        // Hacer que al mismo tiempo el ice ball rote sobre un eje aleatorio, 10 radianes, en 3 segundos
        // Tras llegar a su posicion final, debera ser eliminado de la escena.
        let moveAction = SCNAction.move(to: SCNVector3(x: pos.x, y: 0, z: Float(limits.maxY)), duration: 3)
        let rotateAction = SCNAction.rotateBy(x: CGFloat.random(in: 0...10), y: CGFloat.random(in: 0...10), z: CGFloat.random(in: 0...10), duration: 3)
        let removeAction = SCNAction.removeFromParentNode()
        let sequenceAction = SCNAction.sequence([SCNAction.group([moveAction, rotateAction]), removeAction])
        
        iceBall.runAction(sequenceAction)
    }

}
